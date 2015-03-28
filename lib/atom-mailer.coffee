{CompositeDisposable} = require 'atom'
{$} = require 'atom-space-pen-views'
Imap = require 'imap'
jconv = require 'jconv'
inspect = require('util').inspect
mimelib = require 'mimelib'
inspect = require('util').inspect


createMailerView = (state) ->
  AtomMailerView = require './atom-mailer-view'
  new AtomMailerView(state)

module.exports = AtomMailer =
  atomMailerView: null
  subscriptions: null

  config:
    mailAddress:
      type: "string"
      default: "you@gmail.com"
    mailPassword:
      type: "string"
      default: "password"
    Host:
      type: "string"
      default: "imap.gmail.com"
    Port:
      type: "integer"
      default: 993
    TlsEnable:
      type: "boolean"
      default: true

  initMailSettings: ->
    @mailAddress = atom.config.get('atom-mailer.mailAddress')
    @mailPassword = atom.config.get('atom-mailer.mailPassword')
    @host = atom.config.get('atom-mailer.Host')
    @port = atom.config.get('atom-mailer.Port')
    @tlsEnable = atom.config.get('atom-mailer.TlsEnable')

    @imap = new Imap
      user: @mailAddress
      password: @mailPassword
      host: @host
      port: @port
      tls: @tlsEnable

  activate: (state) ->
    atom.workspace.addOpener (uri) =>
      if uri is 'atom-mailer://inbox'
        @atomMailerView = createMailerView(state)

        return @atomMailerView
      else
        return

    @initMailSettings()

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-mailer:open': => @open()

  deactivate: ->
    @subscriptions.dispose()
    #@atomMailerView.destroy()

  parseMailData: (mailDataString) ->
    console.log 'hellooo'
    mailData = {}
    dataArr = mailDataString.split("\n")

    indexKey = ''
    for i in [0...dataArr.length]
      if dataArr[i].indexOf(':') >= 0
        s = dataArr[i].split(':')
        indexKey = s[0].toLowerCase()

        switch indexKey
          when 'from', 'to'
            mailData[ indexKey ] = s[1]
          when 'subject'
            mailData[ indexKey ] = @convertText s[1]
      else
        switch indexKey
          when 'from', 'to'
            mailData[ indexKey ] += dataArr[i]
          when 'subject'
            mailData[ indexKey ] += @convertText(dataArr[i])

    mailData.from = @parseAddressData(mailData.from)
    mailData.to   = @parseAddressData(mailData.to)

    return mailData

  receiveMail: ->
    @imap.once 'ready', =>
      @openInbox (err, box) =>
        throw err if err
        f = @imap.seq.fetch '1:10',
          bodies: ['HEADER.FIELDS (FROM TO SUBJECT DATE)','TEXT']
          struct: true

        f.on 'message', (msg, seqno) =>
          msg.on 'body', (stream, info) =>
            buffer = ''
            stream.on 'data', (chunk) =>
              buffer += chunk.toString('utf8')

            stream.on 'end', =>
              if info.which isnt 'TEXT'
                parsedHeader = Imap.parseHeader(buffer)
                @storeMessage seqno, parsedHeader, 'header'
                @atomMailerView.addMessage(parsedHeader, seqno)
              else
                #console.log buffer
                @storeMessage seqno, buffer, 'body'
                @atomMailerView.addBody(buffer, seqno)

          msg.on 'attributes', (attrs) =>
            @storeMessage seqno, attrs, 'attrs'

        f.once 'error', (err) =>
          console.log err

        f.once 'end', =>
          @prepareMessages()
          @eventInit()
          @imap.end()

    @imap.once 'error', (err) =>
      if err.code isnt "ECONNRESET"
        console.log err

    @imap.once 'end', =>
      console.log 'end'

  serialize: ->
    #atomMailerViewState: @atomMailerView.serialize()

  openInbox: (cb) ->
    @imap.openBox('INBOX', true, cb)

  jis2utf: (text)->
    buf = new Buffer(text)
    convertedBuf = jconv.convert buf, 'ISO-2022-JP', 'UTF-8'
    return convertedBuf.toString()

  parseAddressData: (txt) ->
    matched = txt.match(/([^<]*)(\<[^>]*\>)/)
    if matched?
      return name: @convertText(matched[1]), address: @trimSomeCharacter(matched[2])
    else
      if @checkEncoding(txt)
        return name: @convertText(txt), address: ''
      else
        return name: '', address: @trimSomeCharacter(txt)

  checkEncoding: (txt) ->
    matched = txt.match(/\=\?([^\?]*)\?[A-Z]\?/)
    if matched?
      return matched[1]
    else
      return null

  eventInit: ->
    callback = (event) =>
      #console.log @mailBox[$(this).attr('seqno')].body
      @atomMailerView.openMessage @mailBox[$(event.target).attr('seqno')]

    @atomMailerView.on 'click', 'a', callback

  storeMessage: (seqno, data, type) ->
    @mailBox = {} if !@mailBox?
    if !@mailBox[seqno]?
      @mailBox[seqno] = {}

    @mailBox[seqno][type] = data

  parseAttrs: ( attrs ) ->
    res =
      part: false
      info: {}

    for v in attrs.struct
      if v.type is 'alternative' || v.type is 'mixed'
        res.part = true
        res.boundary = v.params.boundary
      else
        if attrs.struct.length is 1
          res.info[v.partID] =
            type: v.type
            subtype: v.subtype
            encoding: v.encoding
            charset: v.params.charset
        else
          res.info[v[0].partID] =
            type: v[0].type
            subtype: v[0].subtype
            encoding: v[0].encoding
            charset: v[0].params.charset

    return res

  prepareMessages: ->
    Base64 = require('js-base64').Base64
    for key of @mailBox
      attrs = @parseAttrs(@mailBox[key].attrs)
      if attrs.part
        rawBody = @mailBox[key].body.split( '--' + attrs.boundary )
      else
        rawBody = @mailBox[key].body

      @mailBox[key].body = []

      bodyArr = @ignoreContentInfo rawBody
      for attrKey of attrs.info
        bodyData = bodyArr[attrKey - 1]
        switch attrs.info[attrKey].encoding
          when 'BASE64'
            bodyData = Base64.decode(bodyData)
          when 'QUOTED-PRINTABLE'
            bodyData = mimelib.decodeQuotedPrintable(bodyData)

        switch attrs.info[attrKey].charset
          when 'ISO-2022-JP'
            bodyData = @jis2utf(bodyData)

        @mailBox[key].body.push bodyData

  trimSomeCharacter: (address) ->
    address = address.trim()

    re = /^\<(.*)\>$/

    if address.match(re)
      return address.match(re)[1]
    else
      return address

  ignoreContentInfo: (data) ->
    if typeof data is 'string'
      return [data]
    newArr = []
    for v in data
      if v isnt "" && v isnt "--"
        if v.indexOf('Content-Type') >= 0
          re = /\n*Content[^\n]*\n*/gm
          newArr.push v.replace(re, '')

    return newArr

  open: ->
    atom.workspace.open('atom-mailer://inbox')
    @initMailSettings()
    @receiveMail()
    @imap.connect()
