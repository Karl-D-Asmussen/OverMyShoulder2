#include <stdio.h>

int main(int argc, char *argv[]) {
  const char *str = "plaintext"; 
  int c = 0; 
  if (2 == argc)
    str = argv[1];

  printf("[{\"unMeta\":{}},[{\"t\":\"CodeBlock\",\"c\":[[\"code\",[\"%s\",\"numberLines\"],[[\"startFrom\",\"1\"]]],\"",str);
  
  while (EOF != (c = getchar())) {
    switch (c) {
      case '\n':
        putchar('\\');
        putchar('n');
        break;
      case '\\':
        putchar('\\');
        putchar('\\');
        break;
      case '"':
        putchar('\\');
        putchar('"');
        break;
      default:
        putchar(c);
        break;
    }
  }
 
  printf("\"]}]]");
}
