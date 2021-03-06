{System, ChargedSystem} = require '../BaseSystem'
{Torpedo} = require '../Torpedo'
Cargo = require '../Cargo'
C = require '../Constants'


up_to = ( n ) ->
    Math.floor(Math.random() * n)

TORPEDO_STATUS =
    EMPTY: "Empty"
    LOADING: "Loading"
    LOADED: "Loaded"
    OFFLINE: "Offline"


class WeaponsTargetingSystem extends System

    @POWER = { min : 0.1, max : 1.7, dyn : 1e4 }

    constructor: ( @name, @deck, @section ) ->

        super @name, @deck, @section, WeaponsTargetingSystem.POWER


    set_target: ( @target, @target_deck, @target_section ) -> @target.name


    clear: ->

        @target = undefined
        @target_deck = undefined
        @target_section = undefined



class PhaserSystem extends ChargedSystem

    @POWER = { min : 0.2, max : 1.8, dyn : 1e4 }

    @CHARGE_TIME = 5e3

    @DAMAGE = 1e4
    @RANGE = 1000 * 1000
    @WARP_RANGE = 5 * 1000

    constructor: ( @name, @deck, @section ) ->

        super @name, @deck, @section, PhaserSystem.POWER
        @_repair_reqs = []
        @_repair_reqs[Cargo.COMPUTER_COMPONENTS] = up_to 2.5
        @_repair_reqs[Cargo.EPS_CONDUIT] = up_to 15
        @_repair_reqs[Cargo.WEAPONS_SYSTEMS] = 5
        @charge_time = PhaserSystem.CHARGE_TIME


    power_report: ->

        r = super()
        r.targetting = @section
        return r


    intensity: ->

        PhaserSystem.DAMAGE * do @energy_level


class DisruptorSystem extends PhaserSystem

    @POWER = { min : 0.9, max : 1.2, dyn : 2e4 }
    @DAMAGE = 2e4
    @CHARGE_TIME = 8e3

    constructor: ( @name, @deck, @section ) ->

        super @name, @deck, @section, DisruptorSystem.POWER
        @charge_time = DisruptorSystem.CHARGE_TIME


    intensity: ->

        DisruptorSystem.DAMAGE * do @energy_level


class TorpedoSystem extends System

    @LOAD_TIME = 10 * 1000

    @POWER = { min : 0.4, max : 1.5, dyn : 7e3 }

    @RANGE = 300000 * 1000

    @BLAST_RADIUS = 1e5
    @PROBABILITY_OF_IMPACT = 0.3

    @STATUS =
        EMPTY: "Empty"
        LOADING: "Loading"
        LOADED: "Loaded"
        OFFLINE: "Offline"

    constructor: ( @name, @deck, @section, @section_bearing, @consumption_callback ) ->

        super @name, @deck, @section, TorpedoSystem.POWER
        @_repair_reqs = []
        @_repair_reqs[ Cargo.WEAPONS_SYSTEMS ] = up_to 10
        @loaded = false
        @torpedo_state = TORPEDO_STATUS.EMPTY
        @_autoload = false


    status_report: ->

        if not @is_online()
            @torpedo_state = TorpedoSystem.STATUS.OFFLINE
        r =
            status: @torpedo_state
            name: @name


    is_loaded: ->

        if @torpedo_state == TorpedoSystem.STATUS.LOADED and @.is_online()
            return true
        return false


    load: ->

        t = @consumption_callback()
        if t == 0
            # Cannot load, out of torpedoes
            return

        @torpedo_state = TorpedoSystem.STATUS.LOADING

        loaded = () =>
            @torpedo_state = TorpedoSystem.STATUS.LOADED

        setTimeout loaded, TorpedoSystem.LOAD_TIME

        r = { status: TorpedoSystem.STATUS.LOADING }


    fire: ( target, yield_, current_position ) ->

        t = new Torpedo target, yield_
        t.armed = true
        { x, y, z } = current_position
        t.set_position x, y, z

        @consumption_callback()

        @torpedo_state = TorpedoSystem.STATUS.EMPTY
        if @_autoload
            @load()

        return t


    autoload: ( is_enabled ) ->

        @_autoload = is_enabled
        if @_autoload and @torpedo_state == TorpedoSystem.STATUS.EMPTY
            @load()


class ShieldSystem extends ChargedSystem

    @CHARGE_TIME = 15e3

    @INIT_POWER = 0.25

    @POWER ={ min : 0.01, max : 2, dyn : 6e4 }

    @NAVIGATION_POWER = { min: 0.01, max: 2, dyn: 1e5 }


    constructor: ( @name, @deck, @section, @power_thresholds ) ->

        if not @power_thresholds?
            @power_thresholds = ShieldSystem.POWER

        super @name, @deck, @section, @power_thresholds
        @_repair_reqs = []
        @_repair_reqs[ Cargo.COMPUTER_COMPONENTS ] = up_to 2.5
        @_repair_reqs[ Cargo.EPS_CONDUIT ] = up_to 20
        @_repair_reqs[ Cargo.PHASE_COILS ] = up_to 10
        @charge_time = ShieldSystem.CHARGE_TIME


    hit: ( energy_level ) ->

        pct_drain = energy_level / @power_thresholds.dyn
        pct_missed = 1 - @charge

        console.log "#{ @name } hit, #{ pct_drain * 100 }% drain.
        Hit with #{ energy_level }, with power at #{ @power_thresholds.dyn }"

        @charge_down pct_drain, as_pct=true

        # In the event that the charge overpowered the system
        # return the difference in damage
        if pct_drain > 1
            return energy_level - @power_thresholds.dyn

        passed_energy = energy_level * pct_missed


    drain: ( energy_level ) ->

        # A drain is a leech on the shield charge, as opposed to a
        # hit, which is a more sudden discharge, resulting in spillover
        # damage
        #
        # Returns the passed through energy.

        pct_drain = energy_level / @power_thresholds.dyn

        if @charge < pct_drain
            passthrough = ( pct_drain - @charge ) * @power_thresholds.dyn
            @charge = 0
            return passthrough

        @charge -= pct_drain
        return 0


    shield_report: ->

        r =
            charge : @charge
            status : @state
            name : @name
            active: @active
            online: @online


    get_required_power: ->

        { min, max, dyn } = @power_thresholds

        if @online
            return dyn * ShieldSystem.INIT_POWER

        return 0


exports.PhaserSystem = PhaserSystem
exports.DisruptorSystem = DisruptorSystem
exports.TorpedoSystem = TorpedoSystem
exports.ShieldSystem = ShieldSystem
exports.WeaponsTargetingSystem = WeaponsTargetingSystem
