---
title: Leetcode 432. All O'one Data Structure
date: 2024-12-31 10:50:47
tags: Leetcode Hard
---

Design a data structure to store the strings' count with the ability to return the strings with minimum and maximum counts.

Implement the AllOne class:

    AllOne() Initializes the object of the data structure.
    inc(String key) Increments the count of the string key by 1. If key does not exist in the data structure, insert it with count 1.
    dec(String key) Decrements the count of the string key by 1. If the count of key is 0 after the decrement, remove it from the data structure. It is guaranteed that key exists in the data structure before the decrement.
    getMaxKey() Returns one of the keys with the maximal count. If no element exists, return an empty string "".
    getMinKey() Returns one of the keys with the minimum count. If no element exists, return an empty string "".

Note that each function must run in O(1) average time complexity.

## Analysis

This problem requires accessing random value and boundries in constant time.

Hence, a cache replacement algorithm pattern should be used: 
1. Hashing map ensures `inc` and `dec` runs in constant time. Its pairs' value points to another container.
2. To ensure getting max and min value in constant time, ordered linear data structure such as: `std::vector`, `std::list`, should be used. `std::list` is finnaly chosen because its low cost to insert, delete, & relocate elements.


## Solution:
```c++
class AllOne {
public:
    struct data_t {
        std::string key;
        int count;
    };

    AllOne() {}

    inline void inc(std::string key) {
        // std::cout << "inc(" << key << ")\n";
        if(auto it = store_.find(key); it != store_.end()) {
            it->second->count++;
           
            // move the key to the rear side
            auto dst = std::next(it->second);
            while(dst != ordered_seq_.end() && dst->count < it->second->count) {
                dst++;
            }
            ordered_seq_.splice(dst, ordered_seq_, it->second);
        }
        else {
            ordered_seq_.push_front(data_t{std::move(key), 1});
            store_.insert({ordered_seq_.begin()->key, ordered_seq_.begin()});
        }

        // print_list();
    }
    
    inline void dec(std::string key) {
        // std::cout << "dec(" << key << ")\n";
        auto it = store_.find(key);
        if(it->second->count == 1) {
            // erase the key
            ordered_seq_.erase(it->second);
            store_.erase(it);
        }
        else {
            it->second->count--;

            if(it->second != ordered_seq_.begin()) {
                // move the key to the front side
                auto dst = std::next(it->second, -1);
                while(dst != ordered_seq_.begin() && dst->count >= it->second->count) {
                    dst--;
                }
                if(dst->count >= it->second->count)
                    ordered_seq_.splice(dst, ordered_seq_, it->second);
            }
        }

        // print_list();
    }
    
    inline string getMaxKey() {
        if(store_.empty())
            return "";
        return ordered_seq_.rbegin()->key;
        
    }
    
    inline string getMinKey() {
        if(store_.empty())
            return "";
        return ordered_seq_.begin()->key;
    }

    // void print_list() {
    //     for(auto x : ordered_seq_) {
    //         std::cout << "[" << x.key << "=" << x.count << "] ";
    //     }
    //     std::cout << "\n";
    // }

    std::list<data_t> ordered_seq_;
    std::unordered_map<std::string_view, std::list<data_t>::iterator> store_;
};
```
