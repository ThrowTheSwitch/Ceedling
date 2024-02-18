#ifndef SUPERVISOR_H
#define SUPERVISOR_H

int supervisor_delegate(int* worker_loads, int num_workers);
int supervisor_progress(int* worker_loads, int num_workers);

#endif // SUPERVISOR_H
