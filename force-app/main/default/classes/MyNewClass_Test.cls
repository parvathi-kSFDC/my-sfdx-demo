@IsTest
private class MyNewClass_Test {

    @testSetup
    static void setupUser() {
        // Create a normal user to satisfy the "must use System.runAs" rule
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            Alias = 'tuser',
            Email = 'tuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tuser' + System.currentTimeMillis() + '@example.com',
            ProfileId = p.Id
        );
        insert u;
    }

    @IsTest
    static void coversMyNewClass() {
        // Get the user we inserted
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        System.runAs(u) {
            // Call the method under test
            String actual = MyNewClass.ping();

            // 3-arg assert: (expected, actual, message)
            System.assertEquals('pong', actual, 'MyNewClass.ping() should return pong');
        }
    }
}
