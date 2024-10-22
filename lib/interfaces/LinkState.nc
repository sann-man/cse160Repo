interface LinkState {
    command error_t start();
    // event void NeighborDiscovery.done();
    command void floodLSA();
}