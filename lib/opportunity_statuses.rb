class OpportunityStatuses
  def initialize
    @statuses = {
      ## Automated
      inbox: 'stat_mTvmXSJVRhXc8dB8L0G7nUcsK1CCa7uFtVnukknDlYG',
      needs_contacts: 'stat_xr14AzSUhTZKRetu4dzSOT3xaNXcMImfks83EXTMSQA',
      nurturing_contacts: 'stat_hp94XgSeZtCEt3FaUVmU3UKWb1ne77SYOdEwM5gSG49',
      ready_for_sequence: 'stat_a2G67goxEN4bi514XKNTvarnHAz9KSXFXZwJRrx4BXQ',
      retry_sequence: 'stat_EZlDvFrb9F9jj93Okls3fBQAWGTS2LcrMoeKmE4kqRR',
      in_sales_sequence: 'stat_2sDBNOOgHJnpz6MWP6ukMBApCYQxt7m4KRLC76m3nBP',
      waiting: 'stat_Wd2aVyhht9ZEPaTUPymbn3CrWbuLkiN5qfHKCjvzOqF',
      demo_completed: 'stat_tAFzhXiCrkeE0bsqkn8xcUAhHyTeyp6PJuvb5Vjm4ZD',
      proposal_sent: 'stat_OH6GgDhK2uJ1bBySAd0miwsqjcwS5A7vhZRG34ZtsCB',

      ## VIP
      vip_new: 'stat_5SHe17gOvhXavzSedBXLOdzU9h5WudRDMV5ny3ExDw8',
      vip_in_sequence: 'stat_Jayydp8IPb0pkN5HepFkjK6qNNqsisSaP4ShvtzNTj2',
      vip_first_contact: 'stat_CpPzCiBrvDGYFnXVGHPs9tLmJjjOty7qLJzFCMk80jp',
      vip_phone_call: 'stat_3P2yp1RCvFISf8lf8LJkFjpqpZMseDDE7vvc2OcQdoT',
      vip_demo: 'stat_MIYuQiAxqx4ABKPRwZ2tC1hDS1F8fYQALajDXEePEp4',
      vip_waiting: 'stat_1NqYVXzCWNZr1SiRBQnis6vCen9fSdXbV1B6LlMr0oi',
      vip_lost: 'stat_3hQlDXqXrrPiZm82G9QGVkrV1fDErLWzp2xJ33hiesb'
    }
  end

  def get(key)
    @statuses[key]
  end
end
