#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/acpi.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/string.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Antigravity");
MODULE_DESCRIPTION("Wujie 14 Pro ACPI WMI Power Mode Bridge");

#define PROC_FILENAME "wujie_mode"

static struct proc_dir_entry *proc_entry;

static ssize_t wujie_mode_read(struct file *file, char __user *buf, size_t count, loff_t *pos) {
    char kbuf[32];
    int len;
    acpi_status status;
    struct acpi_buffer output = { ACPI_ALLOCATE_BUFFER, NULL };
    union acpi_object *out_obj;
    int val = -1;

    status = acpi_evaluate_object(NULL, "\\_SB.PCI0.LPC0.H_EC.ITSM", NULL, &output);
    if (ACPI_SUCCESS(status) && output.pointer) {
        out_obj = (union acpi_object *)output.pointer;
        if (out_obj->type == ACPI_TYPE_INTEGER) {
            val = (int)out_obj->integer.value;
        }
        kfree(output.pointer);
    }

    len = snprintf(kbuf, sizeof(kbuf), "%d\n", val);
    return simple_read_from_buffer(buf, count, pos, kbuf, len);
}

static ssize_t wujie_mode_write(struct file *file, const char __user *buf, size_t count, loff_t *pos) {
    char kbuf[16] = {0};
    union acpi_object args[3];
    struct acpi_object_list arg_list;
    int mode = 0;
    acpi_status status;
    u8 wmi_buf[8] = { 0x00, 0xFB, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00 };

    if (count >= sizeof(kbuf))
        return -EINVAL;
    if (copy_from_user(kbuf, buf, count))
        return -EFAULT;
    if (kstrtoint(strim(kbuf), 10, &mode) < 0)
        return -EINVAL;

    wmi_buf[4] = (u8)mode;

    args[0].type = ACPI_TYPE_INTEGER;
    args[0].integer.value = 1;
    args[1].type = ACPI_TYPE_INTEGER;
    args[1].integer.value = 1;
    args[2].type = ACPI_TYPE_BUFFER;
    args[2].buffer.length = sizeof(wmi_buf);
    args[2].buffer.pointer = wmi_buf;

    arg_list.count = 3;
    arg_list.pointer = args;

    pr_info("wujie_acpi: calling WMAA with mode %d\n", mode);
    status = acpi_evaluate_object(NULL, "\\_SB.PCI0.WMID.WMAA", &arg_list, NULL);
    if (ACPI_FAILURE(status)) {
        pr_err("wujie_acpi: WMAA call failed: %s\n", acpi_format_exception(status));
        return -EIO;
    }
    pr_info("wujie_acpi: WMAA call succeeded for mode %d\n", mode);
    return count;
}

static const struct proc_ops wujie_proc_ops = {
    .proc_read  = wujie_mode_read,
    .proc_write = wujie_mode_write,
};

static int __init wujie_acpi_init(void) {
    proc_entry = proc_create(PROC_FILENAME, 0666, NULL, &wujie_proc_ops);
    if (!proc_entry)
        return -ENOMEM;
    pr_info("wujie_acpi: loaded /proc/%s\n", PROC_FILENAME);
    return 0;
}

static void __exit wujie_acpi_exit(void) {
    if (proc_entry)
        proc_remove(proc_entry);
    pr_info("wujie_acpi: unloaded\n");
}

module_init(wujie_acpi_init);
module_exit(wujie_acpi_exit);
