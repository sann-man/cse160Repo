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
    // basic LSA vars 
    uint8_t receivedCount = 0;
    uint8_t expectedCount = MAX_NODES;
    uint16_t sequenceNum = 1;
    neighbor_t lsTable[MAX_NEIGHBORS];
    LSA lsa;

    // struct for graph and routing
    typedef struct { 
        uint16_t cost; 
        uint16_t nextHop; 
        bool known; 
    } dijk_node_t; 

    dijk_node_t dijkTable[MAX_NODES]; 
    routing_t routingTable[MAX_NODES]; 
    uint8_t routingTableSize = 0; 

    // Function declarations 
    void buildGraph();
    bool sharedLink(uint16_t node1, uint16_t node2);
    void runDijkstra();
    void createRouting();
    void updateRoutingTable();

    // Initialize LSA 
    void initLSA(LSA* inlsa) {
        uint8_t i;
        uint8_t tupleIndex = 0;
        
        dbg(ROUTING_CHANNEL, "Node %d: Starting LSA initialization\n", TOS_NODE_ID);

        inlsa->src = TOS_NODE_ID;
        inlsa->seq = sequenceNum++;
        inlsa->numTuples = 0;

        call Neighbor.getNeighbor(lsTable);
        
        dbg(ROUTING_CHANNEL, "Node %d: Checking neighbors for LSA\n", TOS_NODE_ID);

        for(i = 0; i < MAX_NEIGHBORS && tupleIndex < MAX_TUPLE; i++) {
            if(lsTable[i].isActive == ACTIVE) {
                dbg(ROUTING_CHANNEL, "Node %d: Adding neighbor %d to LSA\n", TOS_NODE_ID, lsTable[i].neighborID);
                
                inlsa->tupleList[tupleIndex].neighbor = lsTable[i].neighborID;
                inlsa->tupleList[tupleIndex].cost = lsTable[i].linkQuality;
                tupleIndex++;
            }
        }
        
        inlsa->numTuples = tupleIndex;
        dbg(ROUTING_CHANNEL, "Node %d: Finished LSA initialization with %d tuples\n", 
            TOS_NODE_ID, tupleIndex);
    }

    command error_t LinkState.start() {
        dbg(ROUTING_CHANNEL, "Starting LinkState on Node %d\n", TOS_NODE_ID);
        // start periodic timer 
        call LSATimer.startPeriodic(30000);
        return SUCCESS;
    }

    // initialize graph
    void buildGraph() { 
        uint8_t i; 
        dbg(ROUTING_CHANNEL, "Node %d: initializing graph\n", TOS_NODE_ID); 

        for(i = 0; i < MAX_NODES; i++) { 
            dijkTable[i].cost = INFINITE_COST; 
            dijkTable[i].nextHop = 0; 
            dijkTable[i].known = FALSE; 
        }

        dijkTable[TOS_NODE_ID].cost = 0; 
    }

    bool sharedLink(uint16_t node1, uint16_t node2) { 
        uint8_t i = 0; 
        LSA lsa1; 
        LSA lsa2; 
        bool found1 = FALSE; 
        bool found2 = FALSE; 

        if (!call Cache.contains(node1)) { 
            dbg(ROUTING_CHANNEL, "Node %d: Node %d not in cache\n", TOS_NODE_ID, node1);
            return FALSE;
        }
        if(!call Cache.contains(node2)) { 
            dbg(ROUTING_CHANNEL, "Node %d: Node %d not in cache\n", TOS_NODE_ID, node2);
            return FALSE; 
        }

        lsa1 = call Cache.get(node1); 
        lsa2 = call Cache.get(node2); 

        for (i = 0; i < lsa1.numTuples; i++) { 
            if (lsa1.tupleList[i].neighbor == node2) {
                found1 = TRUE; 
                break; 
            }
        }

        for (i = 0; i < lsa2.numTuples; i++) { 
            if (lsa2.tupleList[i].neighbor == node1) { 
                found2 = TRUE; 
                break; 
            }
        }

        return (found1 && found2);
    }

    void runDijkstra() {
        uint8_t i;
        uint8_t currentNode;
        LSA currentLSA;
        uint16_t newCost;
        bool foundNext;

        dbg(ROUTING_CHANNEL, "Node %d: Starting Dijkstra's algorithm\n", TOS_NODE_ID);
        buildGraph();

        while(TRUE) {
            foundNext = FALSE;
            currentNode = 0;
            newCost = INFINITE_COST;

            for(i = 0; i < MAX_NODES; i++) {
                if(!dijkTable[i].known && dijkTable[i].cost < newCost) {
                    currentNode = i;
                    newCost = dijkTable[i].cost;
                    foundNext = TRUE;
                }
            }

            if(!foundNext) break;

            dijkTable[currentNode].known = TRUE;
            dbg(ROUTING_CHANNEL, "Node %d: Processing node %d (cost: %d)\n",
                TOS_NODE_ID, currentNode, dijkTable[currentNode].cost);

            if(call Cache.contains(currentNode)) {
                currentLSA = call Cache.get(currentNode);

                for(i = 0; i < currentLSA.numTuples; i++) {
                    uint16_t neighborId = currentLSA.tupleList[i].neighbor;
                    uint16_t neighborCost = currentLSA.tupleList[i].cost;

                    if(sharedLink(currentNode, neighborId)) {
                        newCost = dijkTable[currentNode].cost + neighborCost;

                        if(newCost < dijkTable[neighborId].cost) {
                            dijkTable[neighborId].cost = newCost;
                            dijkTable[neighborId].nextHop = (currentNode == TOS_NODE_ID) ? 
                                neighborId : dijkTable[currentNode].nextHop;

                            dbg(ROUTING_CHANNEL, "Node %d: Found better path to %d via %d (cost: %d)\n",
                                TOS_NODE_ID, neighborId, dijkTable[neighborId].nextHop, newCost);
                        }
                    }
                }
            }
        }

        dbg(ROUTING_CHANNEL, "Node %d: Completed Dijkstra's algorithm\n", TOS_NODE_ID);
        updateRoutingTable();
    }

    // currentley not working (constant 0 entries)
    void updateRoutingTable() {
        uint8_t i;
        
        dbg(ROUTING_CHANNEL, "Node %d: -------- ROUTING TABLE --------\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, "Dest\tNextHop\tCost\n");
        
        routingTableSize = 0;
        
        for(i = 0; i < MAX_NODES; i++) {
            if(i != TOS_NODE_ID && dijkTable[i].cost != INFINITE_COST) {
                routingTable[routingTableSize].dest = i;
                routingTable[routingTableSize].nextHop = dijkTable[i].nextHop;
                routingTable[routingTableSize].cost = dijkTable[i].cost;
                
                dbg(ROUTING_CHANNEL, "%d\t%d\t%d\n", 
                    routingTable[routingTableSize].dest,
                    routingTable[routingTableSize].nextHop,
                    routingTable[routingTableSize].cost);
                    
                routingTableSize++;
            }
        }
        dbg(ROUTING_CHANNEL, "--------------------------------\n");
    }

    void createRouting() {
        dbg(ROUTING_CHANNEL, "Node %d: Creating routing table\n", TOS_NODE_ID);
        updateRoutingTable(); 
        runDijkstra(); 
    }

    command void LinkState.floodLSA() {
        pack sendPackage;
        
        dbg(ROUTING_CHANNEL, "Node %d: Starting LSA flood process\n", TOS_NODE_ID);
        
        initLSA(&lsa);
        
        dbg(ROUTING_CHANNEL, "Node %d: Preparing flood package\n", TOS_NODE_ID);
        
        sendPackage.src = TOS_NODE_ID;
        sendPackage.dest = AM_BROADCAST_ADDR;
        sendPackage.TTL = MAX_TTL;
        sendPackage.protocol = PROTOCOL_LINKSTATE;
        sendPackage.seq = sequenceNum;
        
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

    command void LinkState.getRouteTable(routing_t* table, uint8_t* size) {
        uint8_t i;
        for(i = 0; i < routingTableSize; i++) {
            table[i] = routingTable[i];
        }
        *size = routingTableSize;
    }

    event void Sender.sendDone(message_t* msg, error_t error) {
        if(error == SUCCESS) {
            dbg(ROUTING_CHANNEL, "Node %d: LSA sent successfully\n", TOS_NODE_ID);
        } else {
            dbg(ROUTING_CHANNEL, "Node %d: Failed to send LSA\n", TOS_NODE_ID);
        }
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        pack* myMsg;
        LSA* recLSA;
        uint8_t i;
        
        if(len != sizeof(pack)) return msg;

        myMsg = (pack*) payload;
        
        if(myMsg->protocol != PROTOCOL_LINKSTATE) {
            return msg;
        }
        
        if(sizeof(LSA) <= PACKET_MAX_PAYLOAD_SIZE) {
            recLSA = (LSA*)myMsg->payload;
            
            dbg(ROUTING_CHANNEL, "Node %d: Received LSA from %d with %d neighbors:\n", 
                TOS_NODE_ID, recLSA->src, recLSA->numTuples);

            // Print LSA contents
            for(i = 0; i < recLSA->numTuples; i++) {
                dbg(ROUTING_CHANNEL, "\t\tNeighbor: %d Cost: %d\n",
                    recLSA->tupleList[i].neighbor,
                    recLSA->tupleList[i].cost);
            }

            // Check for old LSAs
            if(call Cache.contains(recLSA->src)) {
                LSA currLSA = call Cache.get(recLSA->src);
                if(recLSA->seq <= currLSA.seq) {
                    dbg(ROUTING_CHANNEL, "Node %d: Discarding old LSA\n", TOS_NODE_ID);
                    return msg;
                }
            }

            dbg(ROUTING_CHANNEL, "Node %d: Adding LSA to cache\n", TOS_NODE_ID);
            call Cache.insert(recLSA->src, *recLSA);
            receivedCount++;

            // Run Dijkstra's after each LSA
            createRouting();
        }
        
        return msg;
    }

    event void LSATimer.fired() {
        dbg(ROUTING_CHANNEL, "Node %d: LSA Timer fired - sending update\n", TOS_NODE_ID);
        call LinkState.floodLSA();
    }

    event void Neighbor.done() {
        dbg(ROUTING_CHANNEL, "Node %d: NeighborDiscovery Complete\n", TOS_NODE_ID);
        call LinkState.floodLSA();
    }
}
