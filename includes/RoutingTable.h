#ifndef ROUTING_TABLE_H
#define ROUTING_TABLE_H

#include <stdint.h>

//maybe make a max 
#define MAX_NODES 20
#define MAX_NUMBER 65535



typedef struct {
    uint16_t dest;
    uint16_t nexthop;
    uint8_t cost;
    uint16_t BUhop; //backup hop
    uint8_t BUcost;  // backup cost

} routing_t;

//Functions for RotingTable
void floodLSA();
void createRouting();
void initLSA(LSA* lsa);
void buildGraph();


//Check the table
//Update the table
//

#endif 