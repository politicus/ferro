DEFAULT_AMT = 995
  
amt = DEFAULT_AMT

thank_you = (orders) ->
  """<p class="thankyou">Thank you for donating #{orders} order#{'s' unless orders is '1'} of chicken panang!</p>"""

complete = (type, result = null) ->
  name = $('#name').val()
  track 'Donations', type, name, amt
  if type is 'stripe'
    $.post 'http://donate.getferro.com/donations', {token: result.id, name, amt}

  donated = true
  orders = (amt / DEFAULT_AMT).toFixed 2

  $('#donate > img').hide()
  $('#donate > label').hide()
  $('#donate').append thank_you orders

  chrome?.storage?.sync.set {donated, orders}


update_fee = ->
  fee = (Math.max(
    (amt * 0.029) + 30
    0
  )/100).toFixed 2
  $('.stripe').text '$ ' + fee
  
# these took forever to load sometimes, and they blocked viewing the page, so i moved them from head to async
# but then I moved back to head in order to take out the alarming permissions, see issue #9
# add_async_script 'https://checkout.stripe.com/v2/checkout.js'
# add_async_script 'https://coinbase.com/assets/button.js'

$ ->


  # how do you have '-' in attr name in coffeecup?
  $('.coinbase-button')
    .attr('data-code', '5bb2f730894ac0de1df2fff0c3bdd8fe')
    .attr('data-button-style', 'none')
    .attr('data-custom', 'Anonymous Bitcoin')

  chrome?.storage?.sync.get ['donated', 'orders'], (data) ->
    if chrome.extension and data.donated
      $('#donate > img').hide()
      $('#donate > label').hide()
      $('#donate').append thank_you data.orders

  $.get 'http://donate.getferro.com/donations', (data) ->
    for donation, i in JSON.parse(data)
      tr = $("#donations tr:nth-child(#{i+1})")

      # .text escapes html
      tr.find('td:nth-child(1)').text donation.name
      tr.find('td:nth-child(2)').text '$' + (donation.amt/100.0).toFixed 2

      d = new Date(donation.created_at)
      tr.find('td:nth-child(3)').text d.getMonth() + '/' + d.getDate() + '/' + d.getFullYear()

  update_fee()

  $('#amount').on 'change keyup paste input', ->
    new_amt = parseFloat($('#amount').val()) * 100
    if new_amt isnt amt
      amt = new_amt
      update_fee()

  $('#stripe').click (e) ->
    track 'Donation clicks', 'stripe'

    if amt < 50
      alert 'Minimum card charge is 50 cents.'
      return
  
    token = (res) =>
      complete 'stripe', res

    StripeCheckout.open 
      key:         'pk_live_8JM7cWnRQ5aywwea36gqwL81',
      amount:      amt,
      currency:    'usd',
      name:        'Ferro',
      description: 'Donation',
      panelLabel:  'Donate',
      token:       token
      image:       'images/icon-128.gif'

  $('#bitcoin').click ->
    if amt < 50
      alert 'Minimum donation is 50 cents.'
      return

    $('.coinbase-button').attr 'data-custom', $('#name').val()
    track 'Donation clicks', 'bitcoin'
    $(document).trigger 'coinbase_show_modal', '5bb2f730894ac0de1df2fff0c3bdd8fe'
    false

  $(document).on 'coinbase_payment_complete', (e, code) ->
    complete 'bitcoin'
