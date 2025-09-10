trigger AccountHello on Account (before insert) {
    for (Account a : Trigger.new) {
        a.Description = HelloWorld.greet(a.Name);
    }
}
