#include "worker.h"

#define MAXIMUM_WORKERS 20

static int worker_total_work[MAXIMUM_WORKERS] = { 0 };

void worker_start_over(int id)
{
	int i;

	for (i=0; i < MAXIMUM_WORKERS; i++)
	{
		worker_total_work[i] = 0;
	}
}

void worker_work(int id, int hours)
{
	if ((id >= 0) && (id < MAXIMUM_WORKERS)) 
	{
		worker_total_work[id] += hours;
	}
}

int worker_progress(int id)
{
	/* if only the hours spent actually translated to progress, right? */
	if ((id >= 0) && (id < MAXIMUM_WORKERS)) 
	{
		return worker_total_work[id];
	}

	return 0;
}