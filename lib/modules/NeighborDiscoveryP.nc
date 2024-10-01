#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/NeighborTable.h"

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as NeighborDiscoveryTimer;
    uses interface SimpleSend as Sender;
}

implementation {
    
    // Packet of type pack from packet.h
    pack sendPackage;

    // Neighbor table declaration and count of neighbors
    neighbor_t neighborTable[MAX_NEIGHBORS]; 
    uint8_t count = 0;

    // ---------- Start ------------- // 
    // Start discovery process 
    bool neighborDiscoveryStarted = FALSE; 
    command error_t NeighborDiscovery.start() {
        neighborDiscoveryStarted = TRUE; 
        dbg("NeighborDiscovery", "NeighborDiscovery started\n");
        
        call NeighborDiscoveryTimer.startPeriodic(50000); 
        return SUCCESS; 
    }

    // ----- Timer fired ---  // 
    event void NeighborDiscoveryTimer.fired() {
        dbg("NeighborDiscovery", "Sending package\n");
        
        // Prepare HELLO message
        sendPackage.src = TOS_NODE_ID;
        sendPackage.dest = AM_BROADCAST_ADDR;
        sendPackage.seq = 0;
        sendPackage.TTL = 1;
        sendPackage.type = TYPE_REQUEST; 
        sendPackage.protocol = PROTOCOL_PING;
        memcpy(sendPackage.payload, "GOLD", 6);

        // Send the package
        if (call Sender.send(sendPackage, AM_BROADCAST_ADDR) == SUCCESS) {
            dbg("NeighborDiscovery", "Request package sent successfully\n");
        } else {
            dbg("NeighborDiscovery", "Failed to send package\n");
        }
    } 

    command void NeighborDiscovery.checkStartStatus() {
        if (neighborDiscoveryStarted) {
            dbg("NeighborDiscovery", "NeighborDiscovery has been started.\n");  
        } else {
            dbg("NeighborDiscovery", "NeighborDiscovery has not been started.\n");
        }
    }

    //  ----------- Neighbor table functionality  ------------------- //
    // Use Node.nc to handle receiving functionality but other functionality will remain here
    // |-> better for modularity 
    void addNeighbor(neighbor_t* table, uint8_t* countPtr, uint16_t id, uint8_t quality) {
        // Check if neighbor already exists
        uint8_t i; 
        for (i = 0; i < *countPtr; i++) { 
            if (table[i].neighborID == id) { 
                table[i].neighborID = id;
                table[i].linkQuality = quality; 
                table[i].isActive = ACTIVE; 
                return; 
            }
        }

        // Add new neighbor if table is not yet full
        if (*countPtr < MAX_NEIGHBORS) {
            // Add new neighbor at the available slot
            table[*countPtr].neighborID = id;
            table[*countPtr].linkQuality = quality;
            table[*countPtr].isActive = ACTIVE;
            (*countPtr)++;
            dbg("NeighborDiscovery", "Neighbor added: ID = 0%d, Quality = %d\n", id, quality ); 
        } else { 
            dbg("NeighborDiscovery", "Neighbor table is full\n"); 
        }
    }

    neighbor_t get(neighbor_t* table, uint8_t* countPtr){
        uint8_t i;
        for (i = 0; i < *countPtr; i++) { 
            return table[i];
        }

    }

    // ------- Remove neighbors that are no longer active  -----------//
    // marks the neighbor as inactive 

    void removeNeighbor(neighbor_t* table, uint8_t* countPtr, uint16_t id){
        uint8_t i = 0; 
        for(i = 0; i < *countPtr; i++){ 
            if(table[i].isActive == INACTIVE){ 
                table[i].isActive = INACTIVE;  
                dbg("Neighbor discovery", "Neighbor %d removed from ACTIVE list",id); 
                return; 
            }
        }
    }

    command void NeighborDiscovery.handleNeighbor(uint16_t id, uint8_t quality) {
        // call the addNeighbor function 
        addNeighbor(neighborTable, &count, id, quality); 
        removeNeighbor(neighborTable, &count, id); 
        
    }

    command void NeighborDiscovery.getNeighbor(neighbor_t* tableFlood){

        get(tableFlood, &count);


    }

}
