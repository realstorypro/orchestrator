class OpportunityStatuses
  def initialize
    @statuses = {
      waiting: 'stat_Wd2aVyhht9ZEPaTUPymbn3CrWbuLkiN5qfHKCjvzOqF',
      needs_contacts: 'stat_xr14AzSUhTZKRetu4dzSOT3xaNXcMImfks83EXTMSQA',
      nurturing_contacts: 'stat_hp94XgSeZtCEt3FaUVmU3UKWb1ne77SYOdEwM5gSG49',
      ready_for_sequence: 'stat_a2G67goxEN4bi514XKNTvarnHAz9KSXFXZwJRrx4BXQ',
      retry_sequence: 'stat_EZlDvFrb9F9jj93Okls3fBQAWGTS2LcrMoeKmE4kqRR',
      in_sales_sequence: 'stat_2sDBNOOgHJnpz6MWP6ukMBApCYQxt7m4KRLC76m3nBP',
      demo_completed: 'stat_tAFzhXiCrkeE0bsqkn8xcUAhHyTeyp6PJuvb5Vjm4ZD',
      proposal_sent: 'stat_OH6GgDhK2uJ1bBySAd0miwsqjcwS5A7vhZRG34ZtsCB',
      new: 'stat_5SHe17gOvhXavzSedBXLOdzU9h5WudRDMV5ny3ExDw8'
    }
  end

  def get(key)
    @statuses[key]
  end
end
