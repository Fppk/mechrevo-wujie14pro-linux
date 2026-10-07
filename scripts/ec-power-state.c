#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>

#define MMIO_BASE 0xfe800000
#define MMIO_SIZE 0x1000
#define ITSM_OFFSET 0x4e4

static int is_ac_online(void) {
    FILE *f = fopen("/sys/class/power_supply/ADP1/online", "r");
    if (!f) f = fopen("/sys/class/power_supply/ACAD/online", "r");
    if (!f) return 0;
    int val = 0;
    if (fscanf(f, "%d", &val) != 1) val = 0;
    fclose(f);
    return val;
}

int main(int argc, char *argv[]) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open /dev/mem");
        return 1;
    }

    uint8_t *map = (uint8_t *)mmap(NULL, MMIO_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, MMIO_BASE);
    close(fd);

    if (map == MAP_FAILED) {
        perror("mmap");
        return 2;
    }

    uint8_t current_val = map[ITSM_OFFSET];

    if (argc > 1 && strcmp(argv[1], "toggle") == 0) {
        uint8_t next_val;
        if (current_val != 2) {
            next_val = 2; // Switch to Tablet Mode
        } else {
            next_val = is_ac_online() ? 0 : 1; // Switch to Normal Mode
        }
        map[ITSM_OFFSET] = next_val;
        current_val = next_val;
    }

    munmap(map, MMIO_SIZE);
    printf("%d\n", current_val);
    return 0;
}
