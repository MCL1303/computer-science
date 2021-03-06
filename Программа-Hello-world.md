Традиционная программа, которая используется, чтобы для какого-то языка программирования продемонстрировать, как выглядят программы, написанных на нем – это программа, которая печатает строку текста "Hello World!".

На языке Си она выглядит так:

```c
#include <stdio.h>

int main(void)
{
    printf("Hello World!\n");
    return 0;
}
```

Как мы знаем, программа состоит из команд, описывающих, какие действия и в какой последовательности должен выполнять исполнитель. Команды задаются конструкциями языка, которые называются операторами.

Оператор, который собственно и приводит к появлению текста на экране – это оператор, в котором происходит вызов функции `printf`.

Функции можно воспринимать как группировку команд в нечто, что может решать какую-то вспомогательную задачу (подзадачу).

Вызов функции выглядит как имя функции, после которого идут круглые скобки в которых перечисляются аргументы функции.

Функция `printf` печатает текст на экране.

Итак, в первом приближении, можно считать, что программа на языке Си выглядит так:

1\. "Магическое начало":

```c {after: '}'}
#include <stdio.h>

int main(void)
{
```

2\. Наши описания.

В нашем примере – это только один оператор с вызовом функции `printf`:

```c {include: [stdio.h, main_begin.h], after: '}'}
    printf("Hello World!\n");
```

3\. "Магическое окончание":

```c {include: [main_begin.h]}
    return 0;
}
```

Со всей этой "магией" мы тоже разберёмся, но чуточку позже...
