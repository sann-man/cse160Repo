#include "../../includes/am_types.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP, NeighborDiscoveryC as Neigh;
    components new SimpleSendC(AM_PACK);
    Flooding = FloodingP.Flooding;

    components new ListC(uint8_t, 20);

    

    // , components NeighborDiscoveryC as N;
    FloodingP.List -> ListC;

    FloodingP.Neigh -> Neigh;

    FloodingP.Sender -> SimpleSendC;
}
