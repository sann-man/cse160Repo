#include "../../includes/am_types.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP, NeighborDiscoveryC as Neigh;
    Flooding = FloodingP.Flooding;

    // , components NeighborDiscoveryC as N;
    FloodingP.Neigh -> Neigh;
}
