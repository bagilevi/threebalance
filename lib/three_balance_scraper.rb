# encoding: utf-8
require 'mechanize'

String.class_eval do
  # Removes duplicate whitespaces from within and removes all whitespaces from
  # the begginning and end.
  def compact
    gsub(/\s+/, ' ').strip
  end
end

class ThreeBalanceScraper
  # Input your My3 login details
  # Return: array with 3 elements:
  # - balance in pennies
  # - megabytes remaining
  # - days to use internet allowance
  def run(phone_number, password)
    a = Mechanize.new { |agent| }
    a.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    debug "Getting first page"
    page = a.get "https://www.three.co.uk/My3Account/Login"
    debug "Getting first page again"
    page = a.get "https://www.three.co.uk/My3Account/Login"

    sso_url = page.iframes.first.src
    debug "SSO IFrame URL: #{sso_url}"

    login_widget = a.get sso_url

    login_form = login_widget.form_with(name: "login_form")
    debug "Login form found: #{(login_form != nil).inspect}"
    login_form.username = phone_number
    login_form.password = password
    debug "Submitting login form"
    login_result_page = login_form.click_button

    continuation_link = login_result_page.links.first.href
    debug "Continuing to #{continuation_link}"
    account_page = a.get continuation_link
    debug "Going to balance page"
    balance_page = a.click account_page.link_with text: "Your account balance."

    debug "Finding tables"
    table_nodes = balance_page.search("table.balance")

    internet_table, credit_table = nil, nil
    table_nodes.map{|node|
      title = node.search('thead').text.gsub(/\s+/, ' ').strip
      case title
      when /Internet/
        internet_table = InternetBalanceTable.new(node)
      when /Credit/
        credit_table = CreditBalanceTable.new(node)
      end
    }
    [credit_table.pennies_remaining, internet_table.megabytes_remaining, internet_table.days_remaining].tap { |results|
      debug "Returning results: #{results.inspect}"
    }
  end

  def debug s
    puts s
  end

  class BalanceTable < Struct.new(:table_node)
  end

  class InternetBalanceTable < BalanceTable
    def megabytes_remaining
      table_node.search('tr.summary td:last').text.strip
    end

    def last_expiry_date
      table_node.search('tbody:first tr').to_a[1..-1].map{|row_node|
        s = row_node.search('td')[1].text.compact
        if s =~ /(\d{2})\/(\d{2})\/(\d{2})/
          day, mon, year = $1.to_i, $2.to_i, $3.to_i
          Date.new(2000 + year, mon, day)
        else
          raise "Expiry date not found in #{s.inspect}"
        end
      }.max
    end

    def days_remaining
      (last_expiry_date - Date.today).to_i
    end
  end

  class CreditBalanceTable < BalanceTable
    def pounds_remaining_string
      table_node.search('tr.summary td:last').text.strip[/£(\d+\.\d+)/, 1]
    end

    def pennies_remaining
      items = pounds_remaining_string.split('.', 2).map(&:to_i)
      items.first * 100 + items.last
    end
  end

end




