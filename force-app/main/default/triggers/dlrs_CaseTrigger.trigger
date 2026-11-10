/**
 * Runs Declarative Lookup Rollup Summaries (DLRS) roll-ups whose child object is Case.
 * The How-To Request Count roll-up needs it. This is the trigger DLRS generates; DLRS looks for it by this name.
 */
trigger dlrs_CaseTrigger on Case(
  before delete,
  before insert,
  before update,
  after delete,
  after insert,
  after undelete,
  after update
) {
  dlrs.RollupService.triggerHandler(Case.SObjectType);
}
