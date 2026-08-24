#include "files.h"

#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

String_View read_entire_file(char const *path) {
    int const fd = open(path, O_RDONLY);

    struct stat st;
    fstat(fd, &st);

    size_t len = st.st_size;
    char *buffer = malloc(len + 1);

    size_t offset = 0;
    while (offset < len) {
        ssize_t const n = read(fd, buffer + offset, len - offset);
        offset += (size_t)n;
    }

    buffer[len] = '\0';

    close(fd);

    return (String_View){
        .str = buffer,
        .len = len,
    };
}
