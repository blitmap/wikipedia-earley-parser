'use strict'

Array::repeat ?= (n = 1) ->
	copy = @slice()
	@push copy... while --n > 0
	return @

Array::last ?= -> @[@length - 1]

Array::equals ?= (o) ->
	return true  if o is @
	return false unless o instanceof Array
	return false unless @length is o.length
	return false for v, i in @ when v isnt o[i]
	return true

String::repeat ?= (n = 1) -> new Array(n + 1).join @

String::lpad ?= (n = 0, p = ' ') ->
	return @ unless n > @length
	return p.toString()[0].repeat(n - @length) + @

String::rpad ?= (n = 0, p = ' ') ->
	return @ unless n > @length
	return @ + p.toString()[0].repeat(n - @length)

String::pad ?= (n = 0, p = ' ') ->
	return @ unless n > @length
	return @lpad(Math.floor((n + @length) / 2), p).rpad(n, p)

# think of Productions like logical-and matching terms
class Production extends Array
	constructor: ->
		super arguments.length
		@push arguments...

	equals: (o) ->
		return true  if o is @
		return false unless o instanceof Production
		return super

	toString: -> @join ' '

# think of Rules like logical-or matching terms
class Rule extends Array
	constructor: (@name, productions...) ->
		super productions.length
		@push productions...

	toString: -> @name
	# NOTE: original source had "#{@name} -> #{(p.toString() for p in @).join ' | '}" for __repr__

class State
	constructor: (@name, @production, @dot_index, @start_column) ->
		@end_column = null
		@rules = (r for r in @production when r instanceof Rule) # collect non-terminals

	equals: (o) ->
		return true if o is @
		return false unless o instanceof State
		return false unless @name              is o.name
		return false unless @dot_index         is o.dot_index
		return false unless @start_column      is o.start_column
		return false unless @production is o.production or @production.equals?(o.production)
		return true

	toString: ->
		terms = (p.toString() for p in @production)
		terms.splice @dot_index, 0, '$'

		return "#{@name.rpad 5} -> #{terms.join(' ').rpad 16} [#{@start_column}-#{@end_column}]"

	is_complete: -> @dot_index >= @production.length

	next_term: -> @production[@dot_index] unless @is_complete()

# Column is just an Array containing the states we add
class Column extends Array
	constructor: (@index, @token, states...) ->
		# we don't currently make use of `states`
		super states.length
		@push states...

	push_unique: (newstate) ->
		# no duplicates -- use of State.equals() is important
		return false for s in @ when s.equals newstate

		@push newstate
		newstate.end_column = @
		return true

	toString: -> @index

	print_: (completed_only = false) ->
		console.log """
			[#{@index}] #{@token}
			#{'='.repeat 35}
			"""
		for s in @
			if completed_only and not s.is_complete()
				continue
			console.log s.toString()

		console.log()

class Node
	constructor: (@value, @children) ->

	print_: (level = 0) ->
		console.log ' '.repeat(level) + @value
		c.print_ level + 1 for c in @children

predict = (col, rule) -> col.push_unique new State rule.name, t, 0, col for t in rule

scan = (col, state, token) ->
	return unless col.token is token

	col.push_unique new State state.name, state.production, state.dot_index + 1, state.start_column

complete = (col, state) ->
	return unless state.is_complete()

	for s in state.start_column
		term = s.next_term()

		continue unless term instanceof Rule

		if term.name is state.name
			col.push_unique new State s.name, s.production, s.dot_index + 1, s.start_column

GAMMA_RULE = 'GAMMA'

parse = (rule, text) ->
	chart = (new Column i, tok for tok, i in [ null ].concat text.toLowerCase().split /\s+/)
	chart[0].push_unique new State GAMMA_RULE, new Production(rule), 0, chart[0]

	for col, i in chart
		# `while` is very important here
		# more Column's get added to `chart` - .length can grow!!!
		x = -1
		while ++x < col.length
			state = col[x]
			if state.is_complete()
				complete col, state
			else
				term = state.next_term()

				if term instanceof Rule
					predict col, term              # non-terminal
				else if i + 1 < chart.length
					scan chart[i + 1], state, term # terminal

		# col.print_ true

	# find gammar rule in last chart column (otherwise fail in a bitchy way)
	throw new Error('no parsings!') unless chart.last()[0]
	
	return s for s in chart.last() when s.name is GAMMA_RULE and s.is_complete()

build_trees = (state) -> build_trees_helper [], state, state.rules.length - 1, state.end_column

build_trees_helper = (children, state, rule_index, end_column) ->
	return [ new Node state, children ] if rule_index < 0

	start_column = rule_index is 0 and state.start_column or null

	rule    = state.rules[rule_index]
	outputs = []

	for s in end_column
		break if s is state
		continue if not s.is_complete()
		continue if s.name isnt rule.name
		continue if start_column isnt null and start_column isnt s.start_column

		for sub_tree in build_trees s
			for node in build_trees_helper [ sub_tree ].concat(children), state, rule_index - 1, s.start_column
				outputs.push node

	return outputs

SYM  = new Rule 'SYM',  new Production 'a'
OP   = new Rule 'OP',   new Production '+'
EXPR = new Rule 'EXPR', new Production SYM
EXPR.push new Production EXPR, OP, EXPR

for i in [1 ... 9]
	text   = [ 'a' ].repeat(i).join ' + '
	q0     = parse EXPR, text
	forest = build_trees q0
	console.log "#{forest.length} #{text}"
			
N  = new Rule 'N',  new Production('time'),  new Production('flight'), new Production('banana'), new Production('flies'), new Production('boy'), new Production('telescope')
D  = new Rule 'D',  new Production('the'),   new Production('a'),      new Production('an')
V  = new Rule 'V',  new Production('book'),  new Production('eat'),    new Production('sleep'),  new Production('saw')
P  = new Rule 'P',  new Production('with'),  new Production('in'),     new Production('on'),     new Production('at'),    new Production('through')
PP = new Rule 'PP'
NP = new Rule 'NP', new Production(D, N),   new Production('john'),   new Production('houston')
NP.push new Production NP, PP
PP.push new Production P, NP
VP = new Rule 'VP', new Production V, NP
VP.push new Production VP, PP
S  = new Rule 'S',  new Production(NP, VP), new Production VP

for tree in build_trees parse S, 'book the flight through houston'
	console.log "--------------------------"
	tree.print_()

for tree in build_trees parse S, 'john saw the boy with the telescope'
	console.log "--------------------------"
	tree.print_()
