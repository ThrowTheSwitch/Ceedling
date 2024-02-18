#ifndef WORKER_H
#define WORKER_H

void worker_start_over(int id);
void worker_work(int id, int hours);
int  worker_progress(int id);

#endif // WORKER_H
