#ifndef NEIGHBOR_TABLE_H
#define NEIGHBOR_TABLE_H

#include <stdint.h>

// Define constants
#define MAX_NEIGHBORS 20 // Maximum number of neighbors to track
#define ACTIVE 1
#define INACTIVE 0

// Define the structure for neighbor information
typedef struct {
    uint16_t nodeID;
    uint16_t neighborID;  // ID of the neighbor
    uint16_t linkQuality;  // Link quality (0-255)
    uint16_t isActive;     // Status of the link (ACTIVE/INACTIVE)
} neighbor_t;

// Function prototypes
void addNeighbor(neighbor_t* table, uint8_t* count, uint16_t id, uint8_t quality);
void removeNeighbor(neighbor_t* table, uint8_t* count, uint16_t id);
void get(neighbor_t* table, uint8_t* count);
void neighborFlood(uint8_t nodeID);

#endif // NEIGHBOR_TABLE_H
