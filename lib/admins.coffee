names = [
  # The one who makes the birds sing #
  'JohnONolan',
  # The one who cusses like a sailor #
  'HannahWolfe',
  # The one who is also from Austria #
  'sebgie',
  # The one who knows all the memes #
  'javorszky',
  # The one who is the master of Azure #
  'gotdibbs',
  # The one who runs the bot #
  'jgable',
  # The one who is King of tests #
  'jtw',
  # The one who wanders Wyoming #
  'novaugust',
  # The Darth Vapor #
  'pauladamdavis'
]

regexes = (new RegExp("^#{name}$") for name in names)

module.exports = { names, regexes }