/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "supervisor.h"

int supervisor_delegate(int* worker_loads, int num_workers)
{
	int i;
	int most_bored_id = 0;
	int most_bored_hours = 999999;

	if ((num_workers < 0) || (worker_loads == 0))
		return -1;

	for (i=0; i < num_workers; i++)
	{
		if (worker_loads[i] < most_bored_hours)
		{
			most_bored_hours = worker_loads[i];
			most_bored_id = i;
		}
	}

	return most_bored_id;
}

int supervisor_progress(int* worker_loads, int num_workers)
{
	int i;
	int total_hours = 0;

	if (worker_loads == 0)
		return 0;

	for (i=0; i < num_workers; i++)
	{
		total_hours += worker_loads[i];
	}
	
	return total_hours;
}
