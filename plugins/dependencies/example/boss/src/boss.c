/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "boss.h"
#include "supervisor.h"
#include "libworker.h"

#define MAXIMUM_WORKERS 20

STATIC int hours_worked[MAXIMUM_WORKERS];
STATIC int total_workers = 0;
STATIC int total_hours = 0;

void boss_start()
{
	int i = 0;

	total_workers = 0;
	total_hours = 0;

	for (i = 0; i < MAXIMUM_WORKERS; i++)
	{
		hours_worked[i] = 0;
	}
}

void boss_hire_workers(int num_workers)
{
	if (num_workers > 0) {
		total_workers += num_workers;
	}
}

void boss_fire_workers(int num_workers)
{
	if (num_workers > total_workers)
	{
		num_workers = total_workers;
	}

	if (num_workers > 0)
	{
		total_workers -= num_workers;
	}
}

int boss_micro_manage(int* chunks_of_work, int num_chunks)
{
	int i;
	int id;

	if ((num_chunks < 0) || (chunks_of_work == 0))
	{
		return -1;
	}

	/* Start of the work iteration */
	for (i = 0; i < total_workers; i++)
	{
		worker_start_over(i);
	}

	/* Distribute the work "fairly" */
	for (i = 0; i < num_chunks; i++)
	{
		id = supervisor_delegate(hours_worked, total_workers);
		if (id >= 0)
		{
			worker_work(id, chunks_of_work[i]);
			hours_worked[id] = worker_progress(id);
		}
	}

	/* How much work was finished? */
	return supervisor_progress(hours_worked, total_workers);
}