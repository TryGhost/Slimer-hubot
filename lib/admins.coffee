names = [
  # The one who makes the birds sing #
  'JohnONolan',
  # The one who cusses like a sailor #
  'HannahWolfe',
  # The one who gambles #
  'matthojo',
  # The one who is also from Austria #
  'sebgie',
  # The one who knows all the memes #
  'javorszky',
  # The one who is the master of Azure #
  'gotdibbs',
  # The one who runs the bot #
  'jgable'
]

regexes = (new RegExp("^#{name}$") for name in names)

module.exports = { names, regexes }