`libev` is basically an event loop, which watches and dispatches the target events. It includes the following parts:
- Event Handle
- IO Multiplexing
- Timer
- Event Loop

## 1. Event Handle `ev_watcher`

`libev` uses `ev_watcher` to monitor and manage various events. Each event type has a corresponding watcher type. Common handles include:
- `ev_io` : monitor `fd` R/W events
- `ev_timer`: timer, support both one-time and repeating time
- `ev_signal`: signal event, E.g. `SIGINT`

The above can be referred to as sub-classes of `ev_watcher`:
```C
typedef struct ev_watcher { 
	int active; 
	int pending; 
	int priority; 
	void *data; 
	void (*cb)(struct ev_loop *loop, struct ev_watcher *w, int revents); 
} ev_watcher;
```
An example of registering a readable standard input event:
```C
ev_io stdin_watcher; 
ev_io_init(&stdin_watcher, stdin_cb, STDIN_FILENO, EV_READ); 
ev_io_start(loop, &stdin_watcher);
```
`ev_io_init` is a macro that expands to the following code, mainly for initializing the watcher, such as setting the callback, `fd`, events, etc.:
```C
do {
    do {
        ((ev_watcher *)(void *)((&stdin_watcher)))->active = ((ev_watcher *)(void *)((&stdin_watcher)))->pending = 0;
        ((ev_watcher *)(void *)(((&stdin_watcher))))->priority = (0);
        (((&stdin_watcher)))->cb = ((stdin_cb)), memmove(&((ev_watcher *)(((&stdin_watcher))))->cb, &(((&stdin_watcher)))->cb, sizeof((((&stdin_watcher)))->cb));
    } while (0);
    do {
        ((&stdin_watcher))->fd = ((0));
        ((&stdin_watcher))->events = ((EV_READ)) | EV__IOFDSET;
    } while (0);
} while (0);
```
`ev_io_start` mainly modifies the `anfds` and `fdchanges` arrays. For watchers that are already active, it returns directly. If it is not active, it sets the `active` and `priority` and uses the head insertion method to insert it into the linked list of the corresponding fd in `anfds`, and sets the current watcher as the head:
```C
wlist_add(&((loop)->anfds)[fd].head, (WL)w);

static __inline__ void
wlist_add(WL *head, WL elem) {
    elem->next = *head;
    *head = elem;
}
```
Insert the fd into the end of the `fdchanges` array:
```C
++((loop)->fdchangecnt);
((loop)->fdchanges)[((loop)->fdchangecnt) - 1] = fd;
```
Set the flag `w->events &= ~EV__IOFDSET;`

## 2. IO Multiplexing

`libev` supports `select`, `poll`, `epoll`
```C
void (*backend_modify)(struct ev_loop *loop, int fd, int oev, int nev);
void (*backend_poll)(struct ev_loop *loop, ev_tstamp timeout);
```
Taking `epoll` as an example, `backend_modify` is `epoll_modify`, and `backend_poll` is `epoll_poll`. `epoll_modify` is the `epoll_ctl` commonly used by everyone. When an event changes, use `EPOLL_CTL_MOD`, otherwise use `EPOLL_CTL_ADD`.
```C
epoll_ctl(backend_fd, oev && oldmask != nev ? EPOLL_CTL_MOD : EPOLL_CTL_ADD, fd, &ev)
```
The execution logic of `epoll_poll` :
- `epoll_wait` obtains the list of ready events (`loop->epoll_events`)
- For ready events, execute `fd_event` and put them into the `pendings` array of the corresponding priority in the loop.
```C
static __inline__ void
fd_event(struct ev_loop *loop, int fd, int revents) {
    ANFD *anfd = ((loop)->anfds) + fd;
    if (__builtin_expect((!!(!anfd->reify)), (1)))
        fd_event_nocheck(loop, fd, revents);
}

static __inline__ void
fd_event_nocheck(struct ev_loop *loop, int fd, int revents) {
    ANFD *anfd = ((loop)->anfds) + fd;
    ev_io *w;
    for (w = (ev_io *)anfd->head; w; w = (ev_io *)((WL)w)->next) {
        int ev = w->events & revents;
        if (ev)
            ev_feed_event(loop, (W)w, ev);
    }
}

void __attribute__((__noinline__))
ev_feed_event(struct ev_loop *loop, void *w, int revents) {
    w_->pending = ++((loop)->pendingcnt)[pri];
    ((loop)->pendings)[pri][w_->pending - 1].w = w_;
    ((loop)->pendings)[pri][w_->pending - 1].events = revents;
}
```

## 3. Timer

The internal implementation of the timer uses a Binary Heap and a Quaternary Heaps (for better cache efficiency).
```C
#define DHEAP 4
#define HEAP0 (DHEAP - 1) /* index of first element in heap */
#define HPARENT(k) ((((k) - HEAP0 - 1) / DHEAP) + HEAP0)
#define UPHEAP_DONE(p,k) ((p) == (k))
```
Note that `HEAP0` is used as the first element, that is, the offset. The internal implementation of the heap is `upheap` and `downheap`, which are relatively simple and will not be described here. Its structure is:
```C
typedef ev_watcher_time *WT;

typedef struct {
    ev_tstamp at;
    WT w;
} ANHE;
```
The heap is sorted according to `at`, which is the expiration time of the timer. The heap sort is sorted according to the value of `at` from small to large.

## 4. Event Loop - `ev_loop`

```C
struct ev_loop *loop = EV_DEFAULT;
ev_run(loop, 0);
```
`EV_DEFAULT` will call the `ev_default_loop` function to initialize an `ev_loop` structure, which mainly initializes the `loop` structure through `loop_init`, such as choosing epoll or poll, select. The most critical point: `epoll_init` occurs when the above loop is created.

`ev_run` is more complicated and mainly does the following:

- `fd_reify`: Traverse the `fdchanges` array mentioned earlier, take out the linked list from `anfds` according to the fd, traverse all event linked lists, get all events, and determine whether the latest event is consistent with the previous old event (`events`). If they are inconsistent, call `epoll_modify` (or add the event for the first time).
```C
typedef struct {
    WL head;    // event linked list
    unsigned char events;
    // other
} ANFD;
```
- `backend_poll`: See the implementation of `backend_poll` above, it will fetch the ready events and put the events into the `pendings` array, that is, put them at the end of the corresponding priority queue.
- `timer_reify`: If the event has not expired, no processing is done. Otherwise, the  executes the following:
    - Call `ev_timer_stop` to clear the timer that has no `repeat` set.
    - Set the `repeat` timer with `ev_timer_init()` call
- `invoke_cb`: it is `ev_invoke_pending` by default, the callback will be take out of from the priority queue then be triggered respectively.

## Reference
[libev | Github](https://github.com/enki/libev)

[Quaternary Heaps | University of Waterloo ECE 250](https://ece.uwaterloo.ca/~dwharder/aads/Algorithms/d-ary_heaps/Quaternary_heaps/)
