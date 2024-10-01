#include "../includes/packet.h"
#include "../includes/protocol.h"
#include "../includes/am_types.h"
#include "../includes/NeighborTable.h" 

configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;
    components new TimerMilliC() as NeighborDiscoveryTimer;
    components new SimpleSendC(AM_PACK);

    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;
    NeighborDiscoveryP.NeighborDiscoveryTimer -> NeighborDiscoveryTimer;
    NeighborDiscoveryP.Sender -> SimpleSendC;
}
