---
title: Architecture of Low-latency Quoting Stream System for Quantitative Trading
date: 2026-02-20 04:32:23
tags: 
    - Stream System
    - HFT
---

## High-Level Architecture

The system follows a modular yet monolithic design moving from data ingestion through decoding, calculation, and distribution.

![](./Quotation_Decoding_System_Diagram.png)

## Data Structure

### L1 Market Data

While L1 Market Data is the standard for retail platforms and low-frequency strategies; it lacks the granularity required for HFT (High-Frequency Trading).

Typical L1 Payload:

```C++
struct L1_Tick {
    char symbol[16];      // Fixed-size char array to avoid heap allocation
    uint64_t exch_time;   // Exchange-generated timestamp (ms)
    uint64_t local_time;  // Local receipt timestamp for latency monitoring
    int64_t bid_price;     // Best bid price
    int64_t bid_size;      // Quantity at best bid
    int64_t ask_price;     // Best ask price
    int64_t ask_size;      // Quantity at best ask
};
```

### L2 Market Data

Level 2 Market Data represents the Depth of Book. It is either Market by Order (MBO) or Market by Price (MBP).

In the Shanghai and Shenzhen Stock Exchanges (SSE/SZSE), the Level 2 data is MBO feed. Instead of receiving aggregated price levels, the exchange broadcasts every individual limit order and transaction. Also 20-level deep of the order book is intergrated into the snapshot.

The L2 Market Data types are: Snapshot, Orderbook, Order, and Transaction. Snapshots and orderbooks are typically broadcast at fixed intervals, while orders and transactions are streamed tick-by-tick.

Typical L2 payload:

```C++
constexpr int MAX_SYMBOL_LEN = 16;
constexpr int BOOK_DEPTH = 20;

struct alignas(64) L2_Order {
    char     symbol[MAX_SYMBOL_LEN];
    uint64_t channel_no;
    uint64_t seq_num;
    uint64_t exch_time;
    int64_t  price;
    int64_t  volume;
    char     side;       //  Buy/Sell
    char     ord_type;   //  Market / Limit / Cancel
};

struct alignas(64) L2_Transaction {
    char     symbol[MAX_SYMBOL_LEN];
    uint64_t channel_no;
    uint64_t seq_num;
    uint64_t buy_ord_seq;
    uint64_t sell_ord_seq;
    uint64_t exch_time;
    int64_t  price;
    int64_t  volume;
    int64_t  turnover;
    char     exec_type;  // Filled / Cancelled
    char     bs_flag;    // Outer Buy/Outer Sell
};

struct alignas(64) L2_Orderbook {
    char     symbol[MAX_SYMBOL_LEN];
    uint64_t exch_time;
    uint64_t local_time;

    // Bids
    int64_t  bid_price[BOOK_DEPTH];
    int64_t  bid_volume[BOOK_DEPTH];
    int32_t  bid_order_count[BOOK_DEPTH];

    // Asks
    int64_t  ask_price[BOOK_DEPTH];
    int64_t  ask_volume[BOOK_DEPTH];
    int32_t  ask_order_count[BOOK_DEPTH];
};

struct alignas(64) L2_Snapshot {
    char     symbol[MAX_SYMBOL_LEN];
    uint64_t exch_time;
    uint64_t local_time;

    int64_t  last_price;
    int64_t  total_volume;
    int64_t  total_turnover;
    
    int64_t  total_bid_volume;
    int64_t  total_ask_volume;
    int64_t  weighted_avg_bid_price;
    int64_t  weighted_avg_ask_price;
};
```

### ML Factors

Matrix of floating values and ternary states.

## Components

### Quotes Adaptors

The ingestion layer abstracts the complexity of upstream connectivity. The adaptor is loaded at the runtime as a dynamic libarary.

- **QuoteBrokerAdaptors**

    The most protocol-intensive component. Upstream sources range from the exchanges' raw UDP broadcast to TCP-based broker's APIs. It manages packet sequencing, handling out-of-order, duplicate, or missing.

- QuoteForwardingAdaptor

    For internal topology, it ingests aggregated or filtered feeds forwarded from other internal network nodes.

- QuoteReplayAdaptor

    Streams historical data from the DB or a raw PCAP file for backtesting and research.

### Stream Decoder & Machine Learning Factor Generator

The Stream Decoder translates raw, fragmented exchange/broker protocols into our internal data structures.

ML Factor Generator is intentional like a black box to the engineering team. The core mathematics remain proprietary to the quantitative team. The generator exposes decoupled interfaces to the quants to inject their models as shared libraries at runtime. The pipeline's memory layout and IPC routing are specifically optimized to handle two distinct signal types:

 - Regression Outputs: High-precision floating-point values. These typically represent continuous metrics, such as slight deviations from the top-of-book price or real-time fair-value calculations.

 - Classification Outputs: Discrete ternary states (-1, 0, 1). These serve as the directional triggers.

### Dispatcher & Sinks

- **IPC sink**: 

    The critical path for execution, utilizing a Single-Producer, Multiple-Consumer (1-Writer, M-Readers) lock-free shared memory architecture.

    The SHM segment begins with a control header includes the Provider PID and Launch Timestamp. During startup, the Feed Handler performs a mandatory check on the stored PID & launch time. If an active process is detected, the new instance aborts to prevent dual-writer memory corruption. The launch timestamp allows downstream readers to detect provider restarts, signaling them to clear stale state and re-synchronize.

- LAN sink: 

    Handles external distribution. It routes data over the network to other colocation facilities

- Log sink: 

    Asynchronously persists the stream into binary files for post-trade database ingestion.

## Further Questions:

The quoting system is a part of the latency arms race. It is unlikely any competitive HFT system will be open sourced.

1. How can we further reduce latency?

Beyond software optimization, we look at Kernel Bypass (using Solarflare Onload or DPDK) to move networking into user-space, avoiding the overhead of the Linux kernel stack. Additionally, CPU Pinning and isolating cores via isolcpus prevents the OS scheduler from interrupting the critical path. For extreme-low-latency requirements, such as HFT arbitrage, the entire system can be offloaded to FPGA hardware.

2. Why Shared Memory, and how is data structured within it?

Shared Memory (SHM) allows multiple processes to access the same physical RAM, eliminating the copy-overhead of local sockets and the expensive context switching between kernel and user space. We structure this as a Lock-Free Single-Producer, Multiple-Consumer (SPMC) ring buffer using Atomic Sequence Numbers.