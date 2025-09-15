@IsTest
private class MyNewClass_Test {
    
    @testSetup
    static void setupData() {
        // Create a Standard User to use with System.runAs
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User u = new User(
            Alias = 'stdusr',
            Email = 'stduser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'stduser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
    }

    @IsTest
    static void coversMyNewClass() {
        // Fetch the test user
        User u = [SELECT Id FROM User WHERE Alias='stdusr' LIMIT 1];
        
        // Run the test logic under that user’s context
        System.runAs(u) {
            // Act
            String result = MyNewClass.ping();
            
            // Assert (3 parameters: expected, actual, message)
            System.assertEquals('pong', result, 'MyNewClass.ping() should return pong');
        }
    }
}
