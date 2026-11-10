/**
 * The test DLRS generates for dlrs_CaseTrigger. It fails if org configuration or other code stops the trigger from running.
 */
@IsTest
private class dlrs_CaseTest {
  @IsTest
  private static void testTrigger() {
    dlrs.RollupService.testHandler(new Case());
  }
}
