#include "../../includes/packet.h"
#include "../../includes/RoutingTable.h"
#include "../../includes/NeighborTable.h"
#include "../../includes/LSA.h"
#include <Timer.h>

module LinkStateP {
    provides interface LinkState;
    
    uses interface SimpleSend as Sender;
    uses interface Receive as Receiver;
    uses interface Hashmap<LSA> as Cache;
    uses interface NeighborDiscovery as Neighbor;
    uses interface Timer<TMilli> as LSATimer;
}

implementation {
    uint8_t receivedCount = 0;
    uint8_t expectedCount = MAX_NODES;
    uint16_t sequenceNum = 1;
    neighbor_t lsTable[MAX_NEIGHBORS];
    LSA lsa;

    // initialize LSA 
    void initLSA(LSA* inlsa) {
        uint8_t i;
        uint8_t tupleIndex = 0;
        
        dbg(ROUTING_CHANNEL, "Node %d: Starting LSA initialization\n", TOS_NODE_ID);

        // initialize the basic LSA fields
        inlsa->src = TOS_NODE_ID;
        inlsa->seq = sequenceNum++;
        inlsa->numTuples = 0;

        // get neighbors list
        call Neighbor.getNeighbor(lsTable);
        
        dbg(ROUTING_CHANNEL, "Node %d: Checking neighbors for LSA\n", TOS_NODE_ID);

        // add active neighbors to LSA
        for(i = 0; i < MAX_NEIGHBORS && tupleIndex < MAX_TUPLE; i++) {
            if(lsTable[i].isActive == ACTIVE) {
                dbg(ROUTING_CHANNEL, "Node %d: Adding neighbor %d to LSA\n", 
                    TOS_NODE_ID, lsTable[i].neighborID);
                
                inlsa->tupleList[tupleIndex].neighbor = lsTable[i].neighborID;
                inlsa->tupleList[tupleIndex].cost = lsTable[i].linkQuality;
                tupleIndex++;
            }
        }
        
        // update tuples
        inlsa->numTuples = tupleIndex;
        dbg(ROUTING_CHANNEL, "Node %d: Finished LSA initialization with %d tuples\n", 
            TOS_NODE_ID, tupleIndex);
    }

    // Link state start
    command error_t LinkState.start() {
        dbg(ROUTING_CHANNEL, "Starting LinkState on Node %d\n", TOS_NODE_ID);
        call LSATimer.startPeriodic(30000);
        return SUCCESS;
    }

    // link state flood (LSA)
    command void LinkState.floodLSA() {
        pack sendPackage;
        
        dbg(ROUTING_CHANNEL, "Node %d: Starting LSA flood process\n", TOS_NODE_ID);
        
        // initialize the LSA
        initLSA(&lsa);
        
        dbg(ROUTING_CHANNEL, "Node %d: Preparing flood package\n", TOS_NODE_ID);
        
        // Prepare the packet
        sendPackage.src = TOS_NODE_ID;
        sendPackage.dest = AM_BROADCAST_ADDR;
        sendPackage.TTL = MAX_TTL;
        sendPackage.protocol = PROTOCOL_LINKSTATE;
        sendPackage.seq = sequenceNum;
        
        // copy LSA to payload
        if(sizeof(LSA) <= PACKET_MAX_PAYLOAD_SIZE) {
            memcpy(sendPackage.payload, &lsa, sizeof(LSA));
            
            dbg(ROUTING_CHANNEL, "Node %d: Attempting to send LSA\n", TOS_NODE_ID);
            
            if(call Sender.send(sendPackage, AM_BROADCAST_ADDR) == SUCCESS) {
                dbg(ROUTING_CHANNEL, "Node %d: LSA send started\n", TOS_NODE_ID);
            } else {
                dbg(ROUTING_CHANNEL, "Node %d: failed to start LSA send\n", TOS_NODE_ID);
            }
        } else {
            dbg(ROUTING_CHANNEL, "Node %d: ERROR - LSA is too big for payload\n", TOS_NODE_ID);
        }
    }

    // send success or failure 
    event void Sender.sendDone(message_t* msg, error_t error) {
        if(error == SUCCESS) {
            dbg(ROUTING_CHANNEL, "Node %d: LSA sent successfully\n", TOS_NODE_ID);
        } else {
            dbg(ROUTING_CHANNEL, "Node %d: Failed to send LSA\n", TOS_NODE_ID);
        }
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if(len == sizeof(pack)) {
            pack* myMsg = (pack*) payload;
            
            // checks for correct protocol 
            if(myMsg->protocol != PROTOCOL_LINKSTATE) {
                return msg;
            }
            
            if(sizeof(LSA) <= PACKET_MAX_PAYLOAD_SIZE) {
                LSA* recLSA = (LSA*)myMsg->payload;
                
                dbg(ROUTING_CHANNEL, "Node %d: processing LSA from node %d\n", 
                    TOS_NODE_ID, recLSA->src);

                // check for old LSA's
                if(call Cache.contains(recLSA->src)) {
                    LSA currLSA = call Cache.get(recLSA->src);
                    if(recLSA->seq <= currLSA.seq) {
                        dbg(ROUTING_CHANNEL, "Node %d: deleting old LSA\n", TOS_NODE_ID);
                        return msg;
                    }
                }

                // insert LSA in cache
                dbg(ROUTING_CHANNEL, "Node %d: adding LSA into cache\n", TOS_NODE_ID);
                call Cache.insert(recLSA->src, *recLSA);
                receivedCount++;

                if(receivedCount >= expectedCount) {
                    dbg(ROUTING_CHANNEL, "Node %d: Received all expected LSAs\n", TOS_NODE_ID);
                    createRouting();
                }
            }
        }
        return msg;
    }

    event void LSATimer.fired() {
        dbg(ROUTING_CHANNEL, "LSA timer fired on Node %d\n", TOS_NODE_ID);
        call LinkState.floodLSA();
    }

    event void Neighbor.done() {
        dbg(ROUTING_CHANNEL, "Node %d: NeighborDiscovery Complete\n", TOS_NODE_ID);
        call LinkState.floodLSA();
    }

    void createRouting() {
        dbg(ROUTING_CHANNEL, "Node %d: Creating routing table\n", TOS_NODE_ID);
        // Placeholder for now
    }
}