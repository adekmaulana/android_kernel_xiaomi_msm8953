/*
** =============================================================================
** Copyright (c) 2016  Texas Instruments Inc.
**
** This program is free software; you can redistribute it and/or modify it under
** the terms of the GNU General Public License as published by the Free Software
** Foundation; version 2.
**
** This program is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
** FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License along with
** this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
** Street, Fifth Floor, Boston, MA 02110-1301, USA.
**
** File:
**     aw8736-misc.c
**
** Description:
**     misc driver for Texas Instruments AW8736 High Performance 4W Smart Amplifier
**
** =============================================================================
*/


#define DEBUG
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/init.h>
#include <linux/delay.h>
#include <linux/pm.h>
#include <linux/i2c.h>
#include <linux/gpio.h>
#include <linux/regulator/consumer.h>
#include <linux/platform_device.h>
#include <linux/firmware.h>
#include <linux/regmap.h>
#include <linux/of.h>
#include <linux/of_gpio.h>
#include <linux/slab.h>
#include <linux/syscalls.h>
#include <linux/fcntl.h>
#include <linux/miscdevice.h>
#include <asm/uaccess.h>
//#include <dt-bindings/sound/aw8736.h>
#include <linux/i2c-dev.h>
#include <linux/dma-mapping.h>
#include <sound/soc.h>

#define DRV_NAME "aw8736"

#define AW8736_MODE 5

#ifdef CONFIG_MACH_XIAOMI_MARKW
#define EXT_CLASS_D_EN_DELAY 13000
#define EXT_CLASS_D_DIS_DELAY 3000
#define EXT_CLASS_D_DELAY_DELTA 2000
#else
#define EXT_PA_MODE  5
#endif

#define	AW8736_MAGIC_NUMBER	0x32353535	/* '2555' */

#define	SMARTPA_SPK_DAC_VOLUME	 			_IOWR(AW8736_MAGIC_NUMBER, 1, unsigned long)
#define	SMARTPA_SPK_POWER_ON 				_IOWR(AW8736_MAGIC_NUMBER, 2, unsigned long)
#define	SMARTPA_SPK_POWER_OFF 				_IOWR(AW8736_MAGIC_NUMBER, 3, unsigned long)
#define	SMARTPA_SPK_SWITCH_PROGRAM 			_IOWR(AW8736_MAGIC_NUMBER, 4, unsigned long)
#define	SMARTPA_SPK_SWITCH_CONFIGURATION 	_IOWR(AW8736_MAGIC_NUMBER, 5, unsigned long)
#define	SMARTPA_SPK_SWITCH_CALIBRATION	 	_IOWR(AW8736_MAGIC_NUMBER, 6, unsigned long)
#define	SMARTPA_SPK_SET_SAMPLERATE		 	_IOWR(AW8736_MAGIC_NUMBER, 7, unsigned long)
#define	SMARTPA_SPK_SET_BITRATE			 	_IOWR(AW8736_MAGIC_NUMBER, 8, unsigned long)



static int spk_pa_gpio;

static int aw8736_file_open(struct inode *inode, struct file *file)
{

	if (!try_module_get(THIS_MODULE)) return -ENODEV;

	return 0;
}

static int aw8736_file_release(struct inode *inode, struct file *file)
{

	file->private_data = (void*)NULL;
	module_put(THIS_MODULE);
	return 0;
}

static ssize_t aw8736_file_read(struct file *file, char *buf, size_t count, loff_t *ppos)
{
	return count;
}

static ssize_t aw8736_file_write(struct file *file, const char *buf, size_t count, loff_t *ppos)
{
	return count;
}
static void amplifier_enable(void) {
  int i = 0;
	/* Open external audio PA device */
	for (i = 0; i < AW8736_MODE; i++) {
		gpio_direction_output(spk_pa_gpio, false);
		gpio_direction_output(spk_pa_gpio, true);
	}
  /*ret = msm_gpioset_activate(CLIENT_WCD_INT, "ext_spk_gpio");
	if (ret) {
		pr_err("%s: gpio set cannot be de-activated %s\n",
			__func__, "ext_spk_gpio");
		return ret;
	}*/
	usleep_range(EXT_CLASS_D_EN_DELAY,
	EXT_CLASS_D_EN_DELAY + EXT_CLASS_D_DELAY_DELTA);

	pr_debug("%s: Enable external speaker PAs.\n", __func__);
}

static void amplifier_disable(void) {
  gpio_direction_output(spk_pa_gpio, false);
  /*ret = msm_gpioset_suspend(CLIENT_WCD_INT, "ext_spk_gpio");
  if (ret) {
    pr_err("%s: gpio set cannot be de-activated %s\n",
        __func__, "ext_spk_gpio");
    return ret;
  }
  */

  usleep_range(EXT_CLASS_D_DIS_DELAY,
   EXT_CLASS_D_DIS_DELAY + EXT_CLASS_D_DELAY_DELTA);
}

static long aw8736_file_unlocked_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	int ret = 0;

	switch (cmd) {

		case SMARTPA_SPK_POWER_ON:
		{
      amplifier_enable();
		}
		break;

		case SMARTPA_SPK_POWER_OFF:
		{
      amplifier_disable();
		}
		break;

	}

	return ret;
}

static struct file_operations fops =
{
	.owner = THIS_MODULE,
	.read = aw8736_file_read,
	.write = aw8736_file_write,
	.unlocked_ioctl = aw8736_file_unlocked_ioctl,
	.open = aw8736_file_open,
	.release = aw8736_file_release,
};

#define MODULE_NAME	"i2c_smartpa"
static struct miscdevice device =
{
	.minor = MISC_DYNAMIC_MINOR,
	.name = MODULE_NAME,
	.fops = &fops,
};

static int init_gpio(struct platform_device *pdev) {
  spk_pa_gpio = of_get_named_gpio(pdev->dev.of_node, "ext-spk-amp-gpio", 0);
	if (spk_pa_gpio < 0) {
		dev_err(&pdev->dev,
		"%s: error! spk_pa_gpio is :%d\n", __func__, spk_pa_gpio);
	} else {
		if (gpio_request_one(spk_pa_gpio, GPIOF_DIR_OUT, "spk_enable")) {
			pr_err("%s: request spk_pa_gpio  fail!\n", __func__);
		}
	}
	pr_err("%s: [hjf] request spk_pa_gpio is %d!\n", __func__, spk_pa_gpio);
  gpio_direction_output(spk_pa_gpio, 0);
  return 0;
}

static int aw8736_machine_probe(struct platform_device *pdev)
{
	int ret = init_gpio(pdev);
  if (ret) {
    pr_err("Error initializing amplifier gpio: %d\n", ret);
  }
  ret = misc_register(&device);
	if (ret) {
		pr_err("Error registering aw8736 device: %d\n", ret);
    return ret;
	}
	return ret;
}

static int aw8736_machine_remove(struct platform_device *pdev) {
  return 0;
}

static const struct of_device_id aw8736_machine_of_match[]  = {
	{ .compatible = "aw,aw8736", },
	{},
};
static int snd_soc_pm(struct device *dev) {
  return 0;
};

const struct dev_pm_ops pm_ops = {
	.suspend = &snd_soc_pm,
	.resume = &snd_soc_pm,
	.freeze = &snd_soc_pm,
	.thaw = &snd_soc_pm,
	.poweroff = &snd_soc_pm,
	.restore = &snd_soc_pm,
};


static struct platform_driver aw8736_machine_driver = {
	.driver = {
		.name = DRV_NAME,
		.owner = THIS_MODULE,
		.pm = &pm_ops,
		.of_match_table = aw8736_machine_of_match,
	},
	.probe = aw8736_machine_probe,
	.remove = aw8736_machine_remove,
};

static int __init aw8736_machine_init(void)
{
	return platform_driver_register(&aw8736_machine_driver);
}

late_initcall(aw8736_machine_init);

static void __exit aw8736_machine_exit(void)
{
	return platform_driver_unregister(&aw8736_machine_driver);
}
module_exit(aw8736_machine_exit);

MODULE_DESCRIPTION("aw8736 amplifier");
MODULE_LICENSE("GPL v2");
MODULE_ALIAS("platform:" DRV_NAME);
MODULE_DEVICE_TABLE(of, aw8736_machine_of_match);
