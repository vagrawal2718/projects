# MP-3 #
## LAZY Read- Write ##
### Assumptions ###
1. Maximum number of users can be 1500
2. If 2 requests arrive at same time and both have same operation and can be executed at some time t, then their selection is random.
3. If some file is in the process of being deleted, and a request comes up to read/write on it, the request will be immediately denied (keeping in mind the min 1 sec delay between user making the request and lazy processing it)
4. If t is the timeeout time for some process and the request can be taken up at the same sec, cancelling the request will be given priority.
5. In cases where at time t, the last read/write request has finished execution (some requests were finished earlier than t) and a delete is in the queue and some read/write operation pops at t-1 sec, the selection will be random.
6. In case of faulty requests, an error message will be printed 1 sec after the user makign the request.


## LAZY Sort
### Assumptions ###
### Merge Sort ###
1. Distributed merge sort will be used for sorting when number of files>=42
2. Max file name length can be 128 characters when number of files are between 42-(10^5)
3. Maximum value of ID can be 100000

### Count Sort ###
1. Distributed merge sort will be used for sorting when number of files<42
2. Max file name length can be 4 characters when number of files are between 1-41
3. Maximum value of ID can be 100000
4. If max file name length exceeds 4 characters and the sorting criterion is name then the sorting algorithm is switched to merge_sort() irrespective of the number of files.