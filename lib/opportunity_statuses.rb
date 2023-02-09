# Used to lookup close.com opportunity statuses
class OpportunityStatuses
  def initialize
    @statuses = {
      ## Automated Pipeline
      inbox: 'stat_mTvmXSJVRhXc8dB8L0G7nUcsK1CCa7uFtVnukknDlYG',
      needs_contacts: 'stat_xr14AzSUhTZKRetu4dzSOT3xaNXcMImfks83EXTMSQA',
      nurturing_contacts: 'stat_hp94XgSeZtCEt3FaUVmU3UKWb1ne77SYOdEwM5gSG49',
      retry_sequence: 'stat_EZlDvFrb9F9jj93Okls3fBQAWGTS2LcrMoeKmE4kqRR',
      ready_for_sequence: 'stat_a2G67goxEN4bi514XKNTvarnHAz9KSXFXZwJRrx4BXQ',
      in_sales_sequence: 'stat_2sDBNOOgHJnpz6MWP6ukMBApCYQxt7m4KRLC76m3nBP',
      waiting: 'stat_Wd2aVyhht9ZEPaTUPymbn3CrWbuLkiN5qfHKCjvzOqF',

      ## Waiting
      outbox: 'stat_csn1bJL7A7vxarSgtFUUxT8XYEDBQfyhVY41dGyzxBU'
    }
  end

  def get(key)
    @statuses[key]
  end
end
