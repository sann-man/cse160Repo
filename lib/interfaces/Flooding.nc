interface Flooding {
    command void pass();
    command error_t send(pack msg, uint16_t dest); 
    command error_t start();


}
