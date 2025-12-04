#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdint.h>
#include <limits.h>

#define MAX_FILENAME_LENGTH 133
#define THRESHOLD 42
#define MAX_THREADS 8
#define MAX_ID_RANGE 100001
#define MAX_TIMESTAMP_LENGTH 20 // Length of ISO 8601 format timestamps
#define CHAR_SET_SIZE 27
#define PADDING_CHAR ' '

typedef struct
{
    char name[MAX_FILENAME_LENGTH];
    int id;
    char timestamp[20];
} File;

typedef struct
{
    char *name;
    int id;
    char *timestamp;
} FileEntry;

typedef struct
{
    int start;
    int end;
    File *files;
    int thread_id;
} ThreadArg;

typedef struct
{
    FileEntry *entries;
    unsigned long long *keys;
    int start_index;
    int end_index;
    unsigned long long min_key;
    unsigned long long max_key;
    unsigned long long *local_counts;
    unsigned long long *global_counts;
    int thread_id;
    int num_threads;
    int entries_count;
    pthread_barrier_t *barrier;
    pthread_mutex_t *count_mutex;
} ThreadData;

// Global variables
File *files = NULL;
File *sorted_files = NULL;
File *temp_files = NULL;
int fileCount = 0;
char sortCriterion[10];
int *count = NULL;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
FileEntry *output_entries;
char sorting_column[20]; // "Name", "ID", or "Timestamp"

unsigned long long string_to_key(const char *s, int max_length);
void *thread_func(void *arg);
int compare_timestamps(const void *a, const void *b)
{
    const char *ts1 = *(const char **)a;
    const char *ts2 = *(const char **)b;
    return strcmp(ts1, ts2);
}

// Function to extract base filename (before the first dot)
char *extract_base_name(const char *filename)
{
    char *base_name = strdup(filename);
    if (!base_name)
    {
        fprintf(stderr, "Memory allocation failed.\n");
        exit(EXIT_FAILURE);
    }
    char *dot_position = strchr(base_name, '.');
    if (dot_position)
    {
        *dot_position = '\0';
    }
    return base_name;
}
int compare_files(const File *a, const File *b)
{
    if (strcmp(sortCriterion, "ID") == 0)
    {
        return (a->id - b->id);
    }
    else if (strcmp(sortCriterion, "Name") == 0)
    {
        return strcmp(a->name, b->name);
    }
    else if (strcmp(sortCriterion, "Timestamp") == 0)
    {
        return strcmp(a->timestamp, b->timestamp);
    }
    else
    {
        fprintf(stderr, "Invalid sort criterion.\n");
        exit(EXIT_FAILURE);
    }
}

unsigned long long string_to_key(const char *s, int max_length)
{
    unsigned long long key = 0;
    int base = CHAR_SET_SIZE;
    int i;
    char *base_name = extract_base_name(s);
    int length = strlen(base_name);
    int padding = max_length - length;
    for (i = 0; i < padding; i++)
    {
        key = key * base;
    }

    for (i = 0; i < length; i++)
    {
        int value;
        if (base_name[i] >= 'a' && base_name[i] <= 'z')
        {
            value = base_name[i] - 'a' + 1;
        }
        else
        {
            fprintf(stderr, "Invalid character '%c' in filename '%s'. Filenames must be lowercase letters only.\n", base_name[i], s);
            free(base_name);
            exit(EXIT_FAILURE);
        }
        key = key * base + value;
    }

    free(base_name);
    return key;
}
void merge(File *arr, int left, int mid, int right)
{
    int i, j, k;
    int n1 = mid - left + 1;
    int n2 = right - mid;

    File *leftArr = (File *)malloc(n1 * sizeof(File));
    File *rightArr = (File *)malloc(n2 * sizeof(File));

    if (!leftArr || !rightArr)
    {
        fprintf(stderr, "Memory allocation failed in merge function.\n");
        exit(EXIT_FAILURE);
    }

    for (i = 0; i < n1; i++)
        leftArr[i] = arr[left + i];
    for (j = 0; j < n2; j++)
        rightArr[j] = arr[mid + 1 + j];

    i = 0;
    j = 0;
    k = left;

    while (i < n1 && j < n2)
    {
        if (compare_files(&leftArr[i], &rightArr[j]) <= 0)
        {
            arr[k++] = leftArr[i++];
        }
        else
        {
            arr[k++] = rightArr[j++];
        }
    }

    while (i < n1)
        arr[k++] = leftArr[i++];

    while (j < n2)
        arr[k++] = rightArr[j++];

    free(leftArr);
    free(rightArr);
}

void merge_sort_internal(File *arr, int left, int right)
{
    if (left < right)
    {
        int mid = left + (right - left) / 2;
        merge_sort_internal(arr, left, mid);
        merge_sort_internal(arr, mid + 1, right);
        merge(arr, left, mid, right);
    }
}

void *merge_sort_thread(void *arg)
{
    ThreadArg *targ = (ThreadArg *)arg;
    merge_sort_internal(targ->files, targ->start, targ->end);
    return NULL;
}

void merge_sort()
{
    int num_threads = (fileCount < MAX_THREADS) ? fileCount : MAX_THREADS;
    pthread_t threads[MAX_THREADS];
    ThreadArg args[MAX_THREADS];

    int chunk_size = fileCount / num_threads;
    int remainder = fileCount % num_threads;
    int current_pos = 0;

    for (int i = 0; i < num_threads; i++)
    {
        args[i].start = current_pos;
        args[i].end = current_pos + chunk_size - 1 + (i < remainder ? 1 : 0);
        args[i].files = files;
        args[i].thread_id = i;
        current_pos = args[i].end + 1;

        pthread_create(&threads[i], NULL, merge_sort_thread, &args[i]);
    }

    for (int i = 0; i < num_threads; i++)
    {
        pthread_join(threads[i], NULL);
    }

    int num_active_chunks = num_threads;
    int step = 1;

    while (num_active_chunks > 1)
    {
        int merged_chunks = 0;

        for (int i = 0; i < num_active_chunks; i += 2)
        {
            if (i + 1 < num_active_chunks)
            {
                int left = args[i].start;
                int mid = args[i].end;
                int right = args[i + 1].end;

                merge(files, left, mid, right);
                args[merged_chunks].start = args[i].start;
                args[merged_chunks].end = args[i + 1].end;
            }
            else
            {
                args[merged_chunks].start = args[i].start;
                args[merged_chunks].end = args[i].end;
            }
            merged_chunks++;
        }

        num_active_chunks = merged_chunks;
        step++;
    }

    // Copy result to sorted_files
    memcpy(sorted_files, files, fileCount * sizeof(File));
}
void *thread_func(void *arg)
{
    ThreadData *data = (ThreadData *)arg;
    if (!data)
    {
        fprintf(stderr, "Invalid thread data\n");
        return NULL;
    }

    unsigned long long key_range = data->max_key - data->min_key + 1;
    unsigned long long *local_counts = (unsigned long long *)calloc(key_range, sizeof(unsigned long long));
    if (!local_counts)
    {
        fprintf(stderr, "Memory allocation failed for local counts\n");
        return NULL;
    }

    for (int i = data->start_index; i < data->end_index; i++)
    {
        if (i >= data->entries_count)
        {
            fprintf(stderr, "Index out of bounds in thread %d\n", data->thread_id);
            free(local_counts);
            return NULL;
        }
        unsigned long long idx = data->keys[i] - data->min_key;
        local_counts[idx]++;
    }

    // Wait for all threads before updating global counts
    pthread_barrier_wait(data->barrier);

    pthread_mutex_lock(data->count_mutex);
    for (unsigned long long i = 0; i < key_range; i++)
    {
        data->global_counts[i] += local_counts[i];
    }
    pthread_mutex_unlock(data->count_mutex);

    pthread_barrier_wait(data->barrier);

    unsigned long long *positions = (unsigned long long *)calloc(key_range, sizeof(unsigned long long));
    if (!positions)
    {
        fprintf(stderr, "Memory allocation failed for positions array\n");
        free(local_counts);
        return NULL;
    }

    pthread_mutex_lock(data->count_mutex);
    unsigned long long pos = 0;
    for (unsigned long long i = 0; i < key_range; i++)
    {
        positions[i] = pos;
        pos += data->global_counts[i];
    }
    pthread_mutex_unlock(data->count_mutex);

    pthread_barrier_wait(data->barrier);
    for (int i = data->start_index; i < data->end_index; i++)
    {
        unsigned long long key_idx = data->keys[i] - data->min_key;
        unsigned long long output_idx;

        pthread_mutex_lock(data->count_mutex);
        output_idx = positions[key_idx]++;
        pthread_mutex_unlock(data->count_mutex);

        if (output_idx >= (unsigned long long)data->entries_count)
        {
            fprintf(stderr, "Output index out of range in thread %d\n", data->thread_id);
            continue;
        }

        output_entries[output_idx].name = strdup(data->entries[i].name);
        output_entries[output_idx].id = data->entries[i].id;
        output_entries[output_idx].timestamp = strdup(data->entries[i].timestamp);

        if (!output_entries[output_idx].name || !output_entries[output_idx].timestamp)
        {
            fprintf(stderr, "Memory allocation failed for output entry strings\n");
            free(local_counts);
            free(positions);
            return NULL;
        }
    }

    free(local_counts);
    free(positions);
    return NULL;
}

void parse_input()
{
    if (scanf("%d", &fileCount) != 1)
    {
        fprintf(stderr, "Failed to read file count\n");
        exit(1);
    }

    files = malloc(fileCount * sizeof(File));
    sorted_files = malloc(fileCount * sizeof(File));

    if (!files || !sorted_files)
    {
        fprintf(stderr, "Memory allocation failed\n");
        exit(1);
    }

    for (int i = 0; i < fileCount; i++)
    {
        if (scanf("%s %d %s", files[i].name, &files[i].id, files[i].timestamp) != 3)
        {
            fprintf(stderr, "Failed to read file %d\n", i);
            exit(1);
        }
    }

    if (scanf("%s", sortCriterion) != 1)
    {
        fprintf(stderr, "Failed to read sort criterion\n");
        exit(1);
    }
}

void print_files()
{
    printf("%s\n", sortCriterion);
    for (int i = 0; i < fileCount; i++)
    {
        printf("%s %d %s\n", sorted_files[i].name, sorted_files[i].id, sorted_files[i].timestamp);
    }
}

int main()
{
    int num_files;
    FileEntry *entries = NULL;
    unsigned long long *keys = NULL;
    int num_threads = MAX_THREADS;
    pthread_t threads[MAX_THREADS];
    ThreadData thread_data[MAX_THREADS];
    pthread_barrier_t barrier;
    pthread_mutex_t count_mutex = PTHREAD_MUTEX_INITIALIZER;
    int max_name_length=0;
    int i;

    // Read input files
    scanf("%d", &num_files);
    fileCount = num_files;
    files = malloc(fileCount * sizeof(File));
    sorted_files = malloc(fileCount * sizeof(File));

    entries = (FileEntry *)malloc(num_files * sizeof(FileEntry));
    keys = (unsigned long long *)malloc(num_files * sizeof(unsigned long long));

    for (i = 0; i < num_files; i++)
    {
        entries[i].name = (char *)malloc((MAX_FILENAME_LENGTH + 1) * sizeof(char));
        entries[i].timestamp = (char *)malloc((MAX_TIMESTAMP_LENGTH + 1) * sizeof(char));
        scanf("%s %d %s", entries[i].name, &entries[i].id, entries[i].timestamp);

        strcpy(files[i].name, entries[i].name);
        files[i].id = entries[i].id;
        strcpy(files[i].timestamp, entries[i].timestamp);
        if (max_name_length< strlen (entries[i].name))
        {
            max_name_length= strlen (entries[i].name);
        }
    }

    scanf("%s", sorting_column);
    strcpy(sortCriterion, sorting_column);

    pthread_barrier_init(&barrier, NULL, num_threads);

    if (fileCount >= THRESHOLD || max_name_length>5)
    {
        merge_sort();
        print_files();
        free(files);
        free(sorted_files);
    }
    else
    {
        unsigned long long global_min_key = ULLONG_MAX;
        unsigned long long global_max_key = 0;

        if (strcmp(sorting_column, "Timestamp") == 0)
        {
            char **timestamps = (char **)malloc(num_files * sizeof(char *));
            for (i = 0; i < num_files; i++)
            {
                timestamps[i] = entries[i].timestamp;
            }

            for (i = 1; i < num_files; i++)
            {
                char *key = timestamps[i];
                int j = i - 1;

                while (j >= 0 && strcmp(timestamps[j], key) > 0)
                {
                    timestamps[j + 1] = timestamps[j];
                    j = j - 1;
                }
                timestamps[j + 1] = key;
            }

            unsigned long long current_key = 0;
            char *prev_timestamp = NULL;
            char **unique_timestamps = (char **)malloc(num_files * sizeof(char *));
            unsigned long long *timestamp_keys = (unsigned long long *)malloc(num_files * sizeof(unsigned long long));
            int num_unique_timestamps = 0;

            for (i = 0; i < num_files; i++)
            {
                if (prev_timestamp == NULL || strcmp(timestamps[i], prev_timestamp) != 0)
                {
                    prev_timestamp = timestamps[i];
                    unique_timestamps[num_unique_timestamps] = prev_timestamp;
                    timestamp_keys[num_unique_timestamps] = current_key;
                    num_unique_timestamps++;
                    current_key++;
                }
            }

            for (i = 0; i < num_files; i++)
            {
                int j;
                for (j = 0; j < num_unique_timestamps; j++)
                {
                    if (strcmp(entries[i].timestamp, unique_timestamps[j]) == 0)
                    {
                        keys[i] = timestamp_keys[j];
                        break;
                    }
                }
                if (keys[i] < global_min_key)
                    global_min_key = keys[i];
                if (keys[i] > global_max_key)
                    global_max_key = keys[i];
            }

            free(timestamps);
            free(unique_timestamps);
            free(timestamp_keys);
        }
        else if (strcmp(sorting_column, "Name") == 0)
        {
            for (i = 0; i < num_files; i++)
            {
                unsigned long long key = string_to_key(entries[i].name, MAX_FILENAME_LENGTH);
                keys[i] = key;
                if (key < global_min_key)
                    global_min_key = key;
                if (key > global_max_key)
                    global_max_key = key;
            }
        }
        else if (strcmp(sorting_column, "ID") == 0)
        {
            for (i = 0; i < num_files; i++)
            {
                unsigned long long key = (unsigned long long)entries[i].id;
                keys[i] = key;
                if (key < global_min_key)
                    global_min_key = key;
                if (key > global_max_key)
                    global_max_key = key;
            }
        }
        else
        {
            fprintf(stderr, "Invalid sorting column.\n");
            exit(EXIT_FAILURE);
        }
        unsigned long long key_range = global_max_key - global_min_key + 1;

#define MAX_KEY_RANGE 10000000
        if (key_range > MAX_KEY_RANGE)
        {
            fprintf(stderr, "Error: Key range too large for counting sort.\n");
            exit(EXIT_FAILURE);
        }

        unsigned long long *global_counts = (unsigned long long *)calloc(key_range, sizeof(unsigned long long));
        output_entries = (FileEntry *)malloc(num_files * sizeof(FileEntry));
        if (!output_entries)
        {
            fprintf(stderr, "Failed to allocate output entries array\n");
            exit(EXIT_FAILURE);
        }
        int files_per_thread = num_files / num_threads;
        int remainder = num_files % num_threads;
        int start_index = 0;

        for (i = 0; i < num_threads; i++)
        {
            int end_index = start_index + files_per_thread + (i < remainder ? 1 : 0);
            thread_data[i].entries = entries;
            thread_data[i].keys = keys;
            thread_data[i].start_index = start_index;
            thread_data[i].end_index = end_index;
            thread_data[i].min_key = global_min_key;
            thread_data[i].max_key = global_max_key;
            thread_data[i].global_counts = global_counts;
            thread_data[i].thread_id = i;
            thread_data[i].num_threads = num_threads;
            thread_data[i].entries_count = num_files;
            thread_data[i].barrier = &barrier;
            thread_data[i].count_mutex = &count_mutex;
            start_index = thread_data[i].end_index;
        }

        for (i = 0; i < num_threads; i++)
        {
            pthread_create(&threads[i], NULL, thread_func, &thread_data[i]);
        }

        for (i = 0; i < num_threads; i++)
        {
            pthread_join(threads[i], NULL);
        }

        printf("%s\n", sorting_column);
        for (i = 0; i < num_files; i++)
        {
            printf("%s %d %s\n", output_entries[i].name, output_entries[i].id, output_entries[i].timestamp);
        }

        for (i = 0; i < num_files; i++)
        {
            free(entries[i].name);
            free(entries[i].timestamp);
        }
        free(entries);
        free(keys);
        free(global_counts);
        free(output_entries);
        pthread_barrier_destroy(&barrier);
        pthread_mutex_destroy(&count_mutex);
    }

    return 0;
}