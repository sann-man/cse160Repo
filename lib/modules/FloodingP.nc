#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/NeighborTable.h"
#include "../../includes/sendInfo.h"
#include "../../includes/am_types.h"
#include "../../includes/protocol.h"

module FloodingP {
     provides interface Flooding;

    provides interface SimpleSend as Flooder;

    uses interface SimpleSend as Sender;

    uses interface Receive as Receiver;

    //  uses interface NeighborDiscovery as Neighbor;

    


}

implementation {
    pack sendFlood;
    uint16_t sequenceNum = 0;

    // neighbor_t neighborTable[MAX_NEIGHBORS]; 


    command void Flooding.pass() {
        // Dummy implementation
        // uint8_t i;
        // for (i = 0; i < MAX_NEIGHBORS; i++){
        //     neighborTable[i] = neighborDiscovery.getNeighbor()
        // }
    }

    command void Flooding.start(){
        // call Neighbor.getNeighbor(neighborTable); //I want to get neighbor table to use 
    }

    

    command error_t Flooder.send(pack msg, uint16_t dest){ //I want to send from the FLood SRC the 
        // // If its the very first one, save the Flood SRC
        // // if (sequenceNum == 0 ){
        //     msg.src -> TOS_NODE_ID; // Src of the node sending unicast
        //     msg.dest -> myMsg->src; //Destination we want to go
        //     msg.TTL -> MAX_TTL; //TTL
        //     msg.seq -> sequenceNum++; //Sequence Number 
        //     msg.protocol->PROTOCOL_PING;
        //     msg.type -> TOS_NODE_ID; //Flood SRC
        //     // sendFlood.fdest -> 
        // }
        

        if(call Sender.send(sendFlood, AM_BROADCAST_ADDR) == SUCCESS){
             dbg("Flooding", "Unicast Sent Sucessfully\n");
        }
        else{
        dbg("Flooding", "Unicast Sent Failed\n");
        }
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){

        // pack* myMsg = (pack*) payload;
        // if (myMsg->dest ==)
        // //check to see if its a duplicase
        // //if not, add to cache
        // //then unicast to its neighbor
        //     sendFlood.src -> TOS_NODE_ID;
        //     sendFlood.dest -> myMsg->src;
        //     sendFlood.TTL -> MAX_TTL;
        //     sendFlood.seq -> sequenceNum;
        //     sendFlood.protocol->PROTOCOL_PING;
            

        
    }

    // void neighborFlood(){
    //     //Create a function that finds the neighbors





    // }







}
