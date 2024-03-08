#ifndef BOSS_H
#define BOSS_H

void boss_start();
void boss_hire_workers(int num_workers);
void boss_fire_workers(int num_workers);
int boss_micro_manage(int* chunks_of_work, int num_chunks);

#endif 
