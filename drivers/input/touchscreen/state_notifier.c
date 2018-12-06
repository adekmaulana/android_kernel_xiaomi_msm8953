/*
 * Touchscreen State Notifier
 *
 * Copyright (C) 2013-2017, Pranav Vashi <neobuddy89@gmail.com>
 * Copyright (C) 2017, Alex Saiko <solcmdr@gmail.com>
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <linux/export.h>
#include <linux/module.h>
#include <linux/delay.h>
#include <linux/input/state_notifier.h>

#define DEFAULT_SUSPEND_DEFER_TIME	5
#define TAG				"state_notifier"

bool state_suspended;
module_param_named(state_suspended, state_suspended, bool, 0444);

struct work_struct resume_work;
static struct delayed_work suspend_work;
static struct workqueue_struct *susp_wq;
static struct kobject *state_notifier_kobj;

static bool suspend_in_progress;
static unsigned int suspend_defer_time = DEFAULT_SUSPEND_DEFER_TIME;

static BLOCKING_NOTIFIER_HEAD(state_notifier_list);

/**
 * state_register_client - register a client notifier
 * @nb: notifier block to callback on events
 */
int state_register_client(struct notifier_block *nb)
{
	return blocking_notifier_chain_register(&state_notifier_list, nb);
}
EXPORT_SYMBOL_GPL(state_register_client);

/**
 * state_unregister_client - unregister a client notifier
 * @nb: notifier block to callback on events
 */
int state_unregister_client(struct notifier_block *nb)
{
	return blocking_notifier_chain_unregister(&state_notifier_list, nb);
}
EXPORT_SYMBOL_GPL(state_unregister_client);

/**
 * state_notifier_call_chain - notify clients on state_events
 * @val: Value passed unmodified to notifier function
 * @v: pointer passed unmodified to notifier function
 */
int state_notifier_call_chain(unsigned long val, void *v)
{
	return blocking_notifier_call_chain(&state_notifier_list, val, v);
}
EXPORT_SYMBOL_GPL(state_notifier_call_chain);

static void __suspend_work(struct work_struct *work)
{
	state_notifier_call_chain(STATE_NOTIFIER_SUSPEND, NULL);
	msleep_interruptible(50);

	state_suspended = true;
	suspend_in_progress = false;

	pr_info("%s: successfully suspended\n", TAG);
}

static void __resume_work(struct work_struct *work)
{
	state_notifier_call_chain(STATE_NOTIFIER_ACTIVE, NULL);
	msleep_interruptible(50);

	state_suspended = false;

	pr_info("%s: successfully resumed\n", TAG);
}

void state_suspend(void)
{
	pr_info("%s: going into suspend\n", TAG);

	if (state_suspended || suspend_in_progress)
		return;

	suspend_in_progress = true;

	queue_delayed_work_on(0, susp_wq, &suspend_work,
		msecs_to_jiffies(suspend_defer_time * 1000));
}
EXPORT_SYMBOL_GPL(state_suspend);

void state_resume(void)
{
	pr_info("%s: resuming\n", TAG);

	cancel_delayed_work_sync(&suspend_work);
	suspend_in_progress = false;

	if (state_suspended)
		queue_work_on(0, susp_wq, &resume_work);
}
EXPORT_SYMBOL_GPL(state_resume);

static ssize_t show_suspend_defer_time(struct kobject *kobj,
				       struct kobj_attribute *attr,
				       char *buf)
{
	return scnprintf(buf, SZ_8, "%d\n", suspend_defer_time);
}

static ssize_t store_suspend_defer_time(struct kobject *kobj,
					struct kobj_attribute *attr,
					const char *buf, size_t count)
{
	int ret, val;

	ret = sscanf(buf, "%d", &val);
	if (ret != 1 || val < 0 || val > 30 ||
	    val == suspend_defer_time)
		return -EINVAL;

	suspend_defer_time = val;

	return count;
}

static struct kobj_attribute suspend_defer_time_attribute =
	__ATTR(suspend_defer_time, S_IWUSR | S_IRUGO,
		show_suspend_defer_time, store_suspend_defer_time);

static struct attribute *state_notifier_attrs[] = {
	&suspend_defer_time_attribute.attr,
	NULL,
};

static struct attribute_group state_notifier_attr_group = {
	.attrs = state_notifier_attrs,
};

static int __init state_notifier_init(void)
{
	int ret = -EFAULT;

	susp_wq = create_singlethread_workqueue("state_susp_wq");
	if (!susp_wq) {
		pr_err("%s: unable to allocate workqueue\n", TAG);
		goto fail;
	}

	state_notifier_kobj = kobject_create_and_add("state_notifier",
						kernel_kobj);
	if (!state_notifier_kobj) {
		pr_err("%s: unable to create kobject\n", TAG);
		goto fail;
	}

	ret = sysfs_create_group(state_notifier_kobj,
				&state_notifier_attr_group);
	if (ret) {
		pr_err("%s: unable to create sysfs group\n", TAG);
		kobject_put(state_notifier_kobj);
		goto fail;
	}

	INIT_DELAYED_WORK(&suspend_work, __suspend_work);
	INIT_WORK(&resume_work, __resume_work);

fail:
	return ret;
}

subsys_initcall(state_notifier_init);

MODULE_AUTHOR("Pranav Vashi <neobuddy89@gmail.com>");
MODULE_DESCRIPTION("State notifier module");
MODULE_LICENSE("GPLv2");
