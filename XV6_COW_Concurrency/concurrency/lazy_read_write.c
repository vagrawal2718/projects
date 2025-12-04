#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>

#define MAX_USERS 1500
#define RESET "\033[0m"
#define YELLOW "\033[1;33m"
#define PINK "\033[1;35m"
#define WHITE "\033[1;37m"
#define GREEN "\033[1;32m"
#define RED "\033[1;31m"

typedef struct req
{
    int user_id;
    int file_id;
    char operation[10];
    int start_time;
    int req_time;
    int completion_time;
    int completed;
    int priority;
    int print;
    pthread_t thread;
    int thread_created;
    int taken_time;
} req;

typedef struct file
{
    int readers;
    int writers;
    int deleted;
    pthread_mutex_t lock;
} file;

typedef struct ThreadArgs
{
    req *request;
    file *file_states;
    int index;
} ThreadArgs;

int r, w, d;
int n, c, t;
req requests[MAX_USERS];
int request_count = 0;
pthread_mutex_t print_mutex;
pthread_mutex_t time_mutex;
pthread_cond_t time_cond;
int current_time = 0;

int get_operation_priority(const char *operation)
{
    if (strcmp(operation, "READ") == 0)
        return 0;
    if (strcmp(operation, "WRITE") == 0)
        return 1;
    return 2; // DELETE
}
int compare_requests(const void *a, const void *b)
{
    req args1 = *(req *)a;
    req args2 = *(req *)b;
    if (args1.start_time != args2.start_time)
    {
        return args1.start_time - args2.start_time;
    }
    return get_operation_priority(args1.operation) - get_operation_priority(args2.operation);
}
int all_completed()
{
    for (int i = 0; i < request_count; i++)
    {
        if (requests[i].completed == 0)
            return 0;
    }
    return 1;
}

void print_request(int user_id, const char *operation, int file_id, int time)
{
    pthread_mutex_lock(&print_mutex);
    printf(YELLOW "User %d has made request for performing %s on file %d at %d seconds\n" RESET,
           user_id, operation, file_id, time);
    pthread_mutex_unlock(&print_mutex);
}

void print_taken(int user_id, int time)
{
    pthread_mutex_lock(&print_mutex);
    printf(PINK "LAZY has taken up the request of User %d at %d seconds\n" RESET,
           user_id, time);
    pthread_mutex_unlock(&print_mutex);
}

void print_completed(int user_id, int time)
{
    pthread_mutex_lock(&print_mutex);
    printf(GREEN "The request for User %d was completed at %d seconds\n" RESET,
           user_id, time);
    pthread_mutex_unlock(&print_mutex);
}

void print_canceled(int user_id, int time)
{
    pthread_mutex_lock(&print_mutex);
    printf(RED "User %d canceled the request due to no response at %d seconds\n" RESET,
           user_id, time);
    pthread_mutex_unlock(&print_mutex);
}

void print_declined(int user_id, int time)
{
    pthread_mutex_lock(&print_mutex);
    printf(WHITE "LAZY has declined the request of User %d at %d seconds because an invalid/deleted file was requested\n" RESET,
           user_id, time);
    pthread_mutex_unlock(&print_mutex);
}

void print_error(int user_id, const char *operation, int file_id)
{
    pthread_mutex_lock(&print_mutex);
    printf("User %d has made incorrect request for performing %s on file %d\n", user_id, operation, file_id);
    pthread_mutex_unlock(&print_mutex);
}
void *time_keeper(void *arg)
{
    while (1)
    {
        sleep(1);
        pthread_mutex_lock(&time_mutex);
        current_time++;
        pthread_cond_broadcast(&time_cond);
        pthread_mutex_unlock(&time_mutex);
    }
    return NULL;
}

void *handle_request(void *arg)
{
    ThreadArgs *args = (ThreadArgs *)arg;
    req *re = args->request;
    file *file_state = &args->file_states[re->file_id - 1];

    int operation_time;
    if (strcmp(re->operation, "READ") == 0)
    {
        operation_time = r;
    }
    else if (strcmp(re->operation, "WRITE") == 0)
    {
        operation_time = w;
    }
    else
    {
        operation_time = d;
    }

    pthread_mutex_lock(&time_mutex);
    while (current_time < re->taken_time + operation_time)
    {
        pthread_cond_wait(&time_cond, &time_mutex);
    }

    if (!re->completed)
    {
        re->completion_time = current_time;
        re->completed = 1;
        print_completed(re->user_id, current_time);

        if (strcmp(re->operation, "READ") == 0)
        {
            pthread_mutex_lock(&file_state->lock);
            file_state->readers--;
            pthread_mutex_unlock(&file_state->lock);
        }
        else if (strcmp(re->operation, "WRITE") == 0)
        {
            pthread_mutex_lock(&file_state->lock);
            file_state->writers = 0;
            pthread_mutex_unlock(&file_state->lock);
        }
        else if (strcmp(re->operation, "DELETE") == 0)
        {
            pthread_mutex_lock(&file_state->lock);
            file_state->deleted = 1;
            pthread_mutex_unlock(&file_state->lock);
        }
    }
    pthread_mutex_unlock(&time_mutex);
    return NULL;
}

int proceed(file file_states[], req re)
{
    file *file_state = &file_states[re.file_id - 1];
    pthread_mutex_lock(&file_state->lock);

    int can_proceed = 0;
    if (re.completed || re.thread_created)
        return 0;

    if (strcmp(re.operation, "READ") == 0)
    {
        can_proceed = file_state->readers + file_state->writers + 1 <= c;
    }
    else if (strcmp(re.operation, "WRITE") == 0)
    {
        can_proceed = (file_state->writers == 0) &&
                      (file_state->readers + 1 <= c);
    }
    else if (strcmp(re.operation, "DELETE") == 0)
    {
        can_proceed = (file_state->readers == 0) &&
                      (file_state->writers == 0);
    }
    return can_proceed;
}

void lazy_read_write(file file_states[])
{
    pthread_t timer_thread;
    printf("LAZY has woken up!\n");
    pthread_create(&timer_thread, NULL, time_keeper, NULL);

    ThreadArgs **thread_args = malloc(request_count * sizeof(ThreadArgs *));
    for (int i = 0; i < request_count; i++)
    {
        thread_args[i] = malloc(sizeof(ThreadArgs));
        thread_args[i]->request = &requests[i];
        thread_args[i]->file_states = file_states;
        thread_args[i]->index = i;
        requests[i].thread_created = 0;
    }

    while (!all_completed())
    {
        pthread_mutex_lock(&time_mutex);
        int current = current_time;
        pthread_mutex_unlock(&time_mutex);

        for (int i = 0; i < request_count; i++)
        {
            if (requests[i].completed || requests[i].thread_created)
                continue;

            if (current >= requests[i].start_time)
            {
                if (!requests[i].print)
                {
                    print_request(requests[i].user_id, requests[i].operation,
                                  requests[i].file_id, requests[i].start_time);
                    requests[i].print = 1;
                    continue;
                }
                if (requests[i].file_id == 0 || requests[i].file_id > n ||
                    (strcmp(requests[i].operation, "READ") != 0 && strcmp(requests[i].operation, "WRITE") != 0 &&
                     strcmp(requests[i].operation, "DELETE") != 0))
                {
                    print_error(requests[i].user_id, requests[i].operation, requests[i].file_id);
                    requests[i].completed = 1;
                    continue;
                }
                if (current - requests[i].start_time >= t)
                {
                    print_canceled(requests[i].user_id, current);
                    requests[i].completed = 1;
                    continue;
                }
            }
        }
        for (int i = 0; i < request_count; i++)
        {
            if (requests[i].completed || requests[i].thread_created ||
                current < requests[i].start_time + 1) // Ensure at least 1 second delay
                continue;

            file *file_state = &file_states[requests[i].file_id - 1];
            pthread_mutex_lock(&file_state->lock);

            if (file_state->deleted &&
                (strcmp(requests[i].operation, "WRITE") == 0 ||
                 strcmp(requests[i].operation, "READ") == 0))
            {
                print_declined(requests[i].user_id, current);
                requests[i].completed = 1;
                pthread_mutex_unlock(&file_state->lock);
                continue;
            }

            // if current request can proceed
            int can_proceed = 0;
            if (strcmp(requests[i].operation, "READ") == 0)
            {
                can_proceed = file_state->readers + file_state->writers + 1 <= c;
            }
            else if (strcmp(requests[i].operation, "WRITE") == 0)
            {
                can_proceed = (file_state->writers == 0) &&
                              (file_state->readers + 1 <= c);
            }
            else if (strcmp(requests[i].operation, "DELETE") == 0)
            {
                can_proceed = (file_state->readers == 0) &&
                              (file_state->writers == 0);
            }

            if (can_proceed)
            {
                // if any earlier request can also proceed
                int earlier_request_exists = 0;
                pthread_mutex_unlock(&file_state->lock); // Release lock to check other files

                for (int j = 0; j < i; j++)
                {
                    if (!requests[j].completed && !requests[j].thread_created &&
                        current >= requests[j].start_time + 1)
                    { // Check 1 second delay for earlier requests too
                        file *earlier_file_state = &file_states[requests[j].file_id - 1];
                        pthread_mutex_lock(&earlier_file_state->lock);

                        int earlier_can_proceed = 0;
                        if (!earlier_file_state->deleted ||
                            strcmp(requests[j].operation, "DELETE") == 0)
                        {
                            if (strcmp(requests[j].operation, "READ") == 0)
                            {
                                earlier_can_proceed = earlier_file_state->readers +
                                                          earlier_file_state->writers + 1 <=
                                                      c;
                            }
                            else if (strcmp(requests[j].operation, "WRITE") == 0)
                            {
                                earlier_can_proceed = (earlier_file_state->writers == 0) &&
                                                      (earlier_file_state->readers + 1 <= c);
                            }
                            else if (strcmp(requests[j].operation, "DELETE") == 0)
                            {
                                earlier_can_proceed = (earlier_file_state->readers == 0) &&
                                                      (earlier_file_state->writers == 0);
                            }
                        }

                        if (earlier_can_proceed)
                        {
                            // earlier request
                            if (strcmp(requests[j].operation, "READ") == 0)
                            {
                                earlier_file_state->readers++;
                            }
                            else if (strcmp(requests[j].operation, "WRITE") == 0)
                            {
                                earlier_file_state->writers = 1;
                            }
                            else if (strcmp(requests[j].operation, "DELETE") == 0)
                            {
                                earlier_file_state->deleted = 1;
                            }

                            requests[j].taken_time = current;
                            print_taken(requests[j].user_id, current);
                            requests[j].thread_created = 1;
                            pthread_create(&requests[j].thread, NULL, handle_request, thread_args[j]);
                            earlier_request_exists = 1;
                            pthread_mutex_unlock(&earlier_file_state->lock);
                            break;
                        }
                        pthread_mutex_unlock(&earlier_file_state->lock);
                    }
                }

                if (earlier_request_exists)
                continue;
                // current request
                pthread_mutex_lock(&file_state->lock);
                if (strcmp(requests[i].operation, "READ") == 0)
                {
                    file_state->readers++;
                }
                else if (strcmp(requests[i].operation, "WRITE") == 0)
                {
                    file_state->writers = 1;
                }
                else if (strcmp(requests[i].operation, "DELETE") == 0)
                {
                    file_state->deleted = 1;
                }

                requests[i].taken_time = current;
                print_taken(requests[i].user_id, current);
                requests[i].thread_created = 1;
                pthread_create(&requests[i].thread, NULL, handle_request, thread_args[i]);
                pthread_mutex_unlock(&file_state->lock);
            }
            else
            {
                pthread_mutex_unlock(&file_state->lock);
            }
        }
    }
    for (int i = 0; i < request_count; i++)
    {
        if (requests[i].thread_created)
        {
            pthread_join(requests[i].thread, NULL);
        }
        free(thread_args[i]);
    }
    free(thread_args);

    printf("\nLAZY has no more pending requests and is going back to sleep!\n");
    pthread_cancel(timer_thread);
}
int main()
{
    scanf("%d %d %d", &r, &w, &d);
    scanf("%d %d %d", &n, &c, &t);

    file file_states[n];
    for (int i = 0; i < n; i++)
    {
        file_states[i].readers = 0;
        file_states[i].writers = 0;
        file_states[i].deleted = 0;
        pthread_mutex_init(&file_states[i].lock, NULL);
    }

    pthread_mutex_init(&print_mutex, NULL);
    pthread_mutex_init(&time_mutex, NULL);
    pthread_cond_init(&time_cond, NULL);

    while (1)
    {
        char input[100];
        scanf("%s", input);
        if (strcmp(input, "STOP") == 0)
            break;

        requests[request_count].user_id = atoi(input);
        scanf("%d %s %d", &requests[request_count].file_id, requests[request_count].operation, &requests[request_count].req_time);
        requests[request_count].start_time = requests[request_count].req_time;
        requests[request_count].priority = get_operation_priority(requests[request_count].operation);
        requests[request_count].completed = 0;
        requests[request_count].print = 0;
        requests[request_count].thread_created = 0;
        request_count++;
    }

    qsort(requests, request_count, sizeof(req), compare_requests);
    lazy_read_write(file_states);

    for (int i = 0; i < n; i++)
    {
        pthread_mutex_destroy(&file_states[i].lock);
    }
    pthread_mutex_destroy(&print_mutex);
    pthread_mutex_destroy(&time_mutex);
    pthread_cond_destroy(&time_cond);

    return 0;
}