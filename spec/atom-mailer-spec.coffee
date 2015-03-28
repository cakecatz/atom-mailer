AtomMailer = require '../lib/atom-mailer'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "AtomMailer", ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('atom-mailer')

  describe "check some methods", ->
    it "checkEncoding", ->
      txt = '=?ISO-2022-JP?B?GyRCJVUlISVfJV4jVCUrITwlSSVhITwlaxsoSg==?= <mail@ft.family.co.jp>'
      expect(AtomMailer.checkEncoding(txt)).toEqual('ISO-2022-JP')

    it "triming some characters from address string", ->
      txt = '<mail@email.com>'
      expect( AtomMailer.trimSomeCharacter(txt) ).toEqual('mail@email.com')

      txt = ' mail@email.com'
      expect( AtomMailer.trimSomeCharacter(txt) ).toEqual('mail@email.com')

    it "parse Attributes", ->
      attrs = {
        struct: [
          {
            disposition: null
            language: null
            params:
              boundary: "001a11c2473ec9563c05031f08b9"
            type: 'alternative'
          }
          [
            {
              encoding: '7BIT'
              lines: 37
              size: 1491
              type: "text"
              subtype: "plain"
            }
          ]
          [
            {
              lines: 537
              encoding: "BASE64"
              partID: "2"
              size: 41898
              type: "text"
              subtype: "html"
            }
          ]
        ]
        date: ''
        flags: []
        uid: 1
        modseq: "19295"
      }

      #expect( AtomMailer.parseAttrs( attrs ) ).toEqual('')

    it "ignore content information", ->
      txt = "Content-Type: text/plain; charset=ISO-2022-JP; format=flowed; delsp=yes\n\
      Content-Transfer-Encoding: 7bit\n\
      \n\
      $B3FEPO?%A%c%s%M%k$N:G?7F02h$O<!$N$H$*$j$G$9!#(B $B:G?7>pJs$r%a!<%k$G<u?.$9$kEPO?(B\
      $B%A%c%s%M%k$NJQ99!\"$^$?$O%a!<%kG[?.$rDd;_$9$k$K$O!\"%a!<%k(B $B%*%W%7%g%s$K%\"%/%;(B\
      $B%9$7$F$/$@$5$$!#(\
      http://www.youtube.com/account_notifications?feature=em-subs_diges\
      ---------------------------------------------------------------\
      $BEPO?%A%c%s%M%k$N:G?7%\"%C%W%G!<%H$r$*FO$1$7$^$9(\
      ---------------------------------------------------------------\
      http://youtu.be/sOiCQ1v0Vg4?e\
      MACKLEMORE & RYAN LEWIS MERCH STORE RELAUNCH!! SEPT 9TH AT 4PM PST!\
      $B:n@.<T(B: Ryan Lewi\
      ----------------------------------------------------------------$B$3$A$i$b%A%'(B\
      $B%C%/!*(\
      ---------------------------------------------------------------\
      http://youtu.be/ztX0BkO9Lg8?e\
      $B%i%V%i%$%V!*$G6u<*%\"%o!<(\
      $B:n@.<T(B: Antifer\
      -\
      http://youtu.be/Ru9ZTdHCBnA?e\
      $B!ZD9;~4V:n6HMQ![%P%C%O(B $BL>6J%a%I%l!<(B 25$B6J!!9b2;<A(\
      $B:n@.<T(B: ClassicalMusic\
      -\
      http://youtu.be/djUMtRHxhKY?e\
      $B!Z:n6HMQ(BBGM$B!&JY6/MQ(BBGM$B![%j%i%C%/%9%T%\"%N6J=8(B 1$B;~4V(\
      $B:n@.<T(B: YASURAGICO\
      -\
      http://youtu.be/4pcsXLMPOQs?e\
      $BO:O/E*8N;v(B.BB\
      $B:n@.<T(B: morning2k16\
      -\
      http://youtu.be/4k6jHpAkyXc?e\
      Perfume $B%A%g%3%l%$%H!&%G%#%9%3(B / Chocolate Disco ( $B%T%\"%N(B / Piano\
      $B:n@.<T(B: KatsuraN\
      -\
      http://youtu.be/Rv7mgHqbjQs?e\
      $B%\"%K%=%s%a%I%l!<(\
      $B:n@.<T(B: man dee\
      ---------------------------------------------------------------"

      console.log txt.replace(/((Content[^\n]*\n)+\n)/g, '')