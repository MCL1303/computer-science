#!/usr/bin/env stack
{-  stack --resolver=lts-10.0
    script
        --package=aeson
        --package=directory
        --package=filepath
        --package=formatting
        --package=mtl
        --package=process
        --package=temporary
        --package=text
        --package=yaml
-}
{-# OPTIONS_GHC -Werror #-}
{-# OPTIONS_GHC -Wall -Wincomplete-record-updates -Wincomplete-uni-patterns #-}

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

import           Control.Monad.State
import           Control.Monad.Writer
import           Data.Aeson.TH
import           Data.Char
import           Data.Foldable
import           Data.List
import           Data.Maybe
import           Data.Text (Text)
import qualified Data.Text as Text
import           Data.Text.Encoding
import qualified Data.Text.IO as Text
import           Data.Yaml as Yaml
import           Formatting
import           Numeric.Natural
import           System.Directory
import           System.FilePath
import           System.IO.Temp
import           System.Process

data Language = NoLanguage | C
    deriving Show

data SnippetConfig = SnippetConfig
    { after   :: Maybe Text
    , include :: Maybe [FilePath]
    }
    deriving Show

deriveFromJSON defaultOptions ''SnippetConfig

defaultSnippetConfig :: SnippetConfig
defaultSnippetConfig = SnippetConfig {after = Nothing, include = Nothing}

data Snippet = Snippet
    { config    :: SnippetConfig
    , content   :: Text
    , filepath  :: FilePath
    , language  :: Language
    , startLine :: Natural
    }
    deriving Show

main :: IO ()
main = do
    files <- listDirectory "."
    for_ (sort files) $ \file -> case takeExtension file of
        ".md" -> do
            putStr $ file ++ " ...\t"
            checkSnippets file
            putStrLn "OK"
        _ -> pure () -- ignore
    putStrLn "OK"

checkSnippets :: FilePath -> IO ()
checkSnippets = extract >=> traverse_ check

extract :: FilePath -> IO [Snippet]
extract file = do
    fileContents <- Text.readFile file
    let (lastSnippet, snippets) =
            runWriter
                $ (`execStateT` Nothing)
                $ traverse_ parseSnippetLine
                $ zip [1 ..]
                $ Text.lines fileContents
    when (isJust lastSnippet) $ error $ show lastSnippet
    pure $ toList snippets
  where

    parseSnippetLine (lineNo, line) = do
        currentSnippet <- get
        case Text.stripPrefix "```" line of
            Nothing -> case currentSnippet of
                Nothing -> pure ()
                Just (snippet@Snippet { content }) ->
                    put $ Just snippet { content = content <> "\n" <> line }
            Just "" -> case currentSnippet of
                Just snippet -> flush snippet
                Nothing      -> startNoLanguage lineNo
            Just languageSpec -> case Text.break isSpace languageSpec of
                ("c", configText) -> case currentSnippet of
                    Just _  -> error "cannot start snippet inside snippet"
                    Nothing -> start configText lineNo
                (exLanguage, _) ->
                    error $ "unknown language: " ++ show exLanguage

    flush snippet = do
        tell [snippet]
        put Nothing

    startNoLanguage lineNo = put $ Just Snippet
        { config    = defaultSnippetConfig
        , content   = Text.empty
        , filepath  = file
        , language  = NoLanguage
        , startLine = lineNo
        }

    start configText lineNo = put $ Just Snippet
        { config    = decodeConfig configText
        , content   = Text.empty
        , filepath  = file
        , language  = C
        , startLine = lineNo
        }
      where
        decodeConfig =
            fromMaybe defaultSnippetConfig
                . fromRight (error . (msg ++))
                . Yaml.decodeEither
                . encodeUtf8
        msg = formatToString (string % ", line " % int % ": ") file lineNo
        fromRight a = either a id

check :: Snippet -> IO ()
check Snippet { language = NoLanguage } = pure ()
check snippet@Snippet { language = C } =
    withSystemTempDirectory "ComputerScience.test" $ \tmp -> do
        let src = tmp </> "source.c"
        Text.writeFile src
            $  Text.unlines
            $  [ sformat ("#include \"" % string % "\"") inc
               | inc <- fromMaybe [] include
               ]
            ++ [ sformat ("#line " % int % " \"" % string % "\"")
                         startLine
                         filepath
               , content
               , fromMaybe "" after
               ]
        srcDir <- getCurrentDirectory
        callProcess
            "gcc"
            [ "-c"
            , "-I" <> srcDir
            , "-Wall"
            , "-Werror"
            , "-Wextra"
            , "-pedantic"
            , src
            , "-o" <> (src -<.> "o")
            ]
  where
    Snippet { config, content, filepath, startLine } = snippet
    SnippetConfig { after, include }                 = config
