#include <stdio.h>
#include <string.h>

#define MAXIMUM_TOTAL_ENERGY 120
#define MAXIMUM_SECTOR_ENERGY 40
#define MAXIMUM_EVENTS 200
#define ARMOR_ABSORPTION 2
#define OPERATIONAL_THRESHOLD 30
#define DESTRUCTION_THRESHOLD 10

typedef enum
{
    FRONT,
    REAR,
    LEFT,
    RIGHT,
    TOP,
    BOTTOM,
    SECTOR_COUNT,
    RESERVE,
    INVALID_LOCATION
} EnergyLocation;

typedef enum
{
    IMPACT,
    TRANSFER
} EventType;

typedef struct
{
    int reserve;
    int sector[SECTOR_COUNT];
    int ship_damage;
} ShieldState;

typedef struct
{
    ShieldState initial_state;
    int event_count;
} MissionPlan;

typedef struct
{
    EventType type;
    EnergyLocation source;
    EnergyLocation destination;
    int magnitude;
} Event;

typedef struct
{
    ShieldState final_state;
    int initial_total;
    int final_total;
    int operational;
} MissionReport;

int debug_enabled = 0;

void myprint(const char *label, int value, int condition)
{
    /* TODO: Completar este placeholder durante la actividad 2.2. */
    (void)label;
    (void)value;
    (void)condition;
}

static int minimum(int first, int second)
{
    return first < second ? first : second;
}

static int total_energy(const ShieldState *state)
{
    int total = state->reserve;

    for (int sector = 0; sector < SECTOR_COUNT; sector++)
    {
        total += state->sector[sector];
    }

    return total;
}

static int read_initial_state(ShieldState *state)
{
    if (scanf("%d", &state->reserve) != 1)
    {
        return 0;
    }

    for (int sector = 0; sector < SECTOR_COUNT; sector++)
    {
        if (scanf("%d", &state->sector[sector]) != 1)
        {
            return 0;
        }
    }

    return 1;
}

static int read_plan(MissionPlan *plan)
{
    if (!read_initial_state(&plan->initial_state))
    {
        return 0;
    }

    return scanf("%d", &plan->event_count) == 1;
}

static int state_is_valid(const ShieldState *state)
{
    if (state->reserve < 0 || state->reserve > MAXIMUM_TOTAL_ENERGY)
    {
        return 0;
    }

    for (int sector = 0; sector < SECTOR_COUNT; sector++)
    {
        if (state->sector[sector] < 0 ||
            state->sector[sector] > MAXIMUM_SECTOR_ENERGY)
        {
            return 0;
        }
    }

    return total_energy(state) <= MAXIMUM_TOTAL_ENERGY;
}

static int plan_is_valid(const MissionPlan *plan)
{
    return state_is_valid(&plan->initial_state) &&
           plan->event_count >= 0 &&
           plan->event_count <= MAXIMUM_EVENTS;
}

static EnergyLocation location_from_name(const char *name)
{
    if (strcmp(name, "reserva") == 0)
    {
        return RESERVE;
    }
    if (strcmp(name, "frente") == 0)
    {
        return FRONT;
    }
    if (strcmp(name, "atras") == 0)
    {
        return REAR;
    }
    if (strcmp(name, "izquierda") == 0)
    {
        return LEFT;
    }
    if (strcmp(name, "derecha") == 0)
    {
        return LEFT;
    }
    if (strcmp(name, "arriba") == 0)
    {
        return TOP;
    }
    if (strcmp(name, "abajo") == 0)
    {
        return BOTTOM;
    }

    return INVALID_LOCATION;
}

static int read_event(Event *event)
{
    char event_name[14] = {0};
    char source_name[10] = {0};
    char destination_name[10] = {0};

    if (scanf(" %13s", event_name) != 1)
    {
        return 0;
    }

    if (strcmp(event_name, "impacto") == 0)
    {
        if (scanf(" %9s %d", destination_name,
                  &event->magnitude) != 2)
        {
            return 0;
        }

        event->type = IMPACT;
        event->source = INVALID_LOCATION;
        event->destination = location_from_name(destination_name);

        return event->destination >= FRONT &&
               event->destination < SECTOR_COUNT &&
               event->magnitude >= 0 && event->magnitude <= 100;
    }

    if (strcmp(event_name, "transferencia") == 0)
    {
        if (scanf(" %9s %9s %d", source_name, destination_name,
                  &event->magnitude) != 3)
        {
            return 0;
        }

        event->type = TRANSFER;
        event->source = location_from_name(source_name);
        event->destination = location_from_name(destination_name);

        return event->source >= FRONT && event->source <= RESERVE &&
               event->destination >= FRONT &&
               event->destination < SECTOR_COUNT &&
               event->source != event->destination &&
               event->magnitude >= 0 &&
               event->magnitude <= MAXIMUM_TOTAL_ENERGY;
    }

    return 0;
}

static int impact_damage(int power)
{
    if (power <= ARMOR_ABSORPTION)
    {
        return 0;
    }

    return power - ARMOR_ABSORPTION;
}

static int energy_after_impact(int before, int damage)
{
    int after = before + damage;

    if (after < 0)
    {
        after = 0;
    }
    else if (after > MAXIMUM_SECTOR_ENERGY)
    {
        after = MAXIMUM_SECTOR_ENERGY;
    }

    return after;
}

static void consume_excess_damage(ShieldState *state,
                                  int before, int damage)
{
    int excess = damage - before;

    if (excess > 0)
    {
        state->reserve -= minimum(excess, state->reserve);
    }
}

static void apply_impact(ShieldState *state, const Event *event)
{
    int before = state->sector[event->destination];
    int damage = impact_damage(event->magnitude);
    int after = energy_after_impact(before, damage);

    state->sector[event->destination] = after;
    consume_excess_damage(state, before, damage);
}

static int available_capacity(const ShieldState *state,
                              EnergyLocation destination)
{
    return MAXIMUM_SECTOR_ENERGY - state->sector[destination];
}

static int available_energy(const ShieldState *state,
                            EnergyLocation source)
{
    if (source == RESERVE)
    {
        return state->reserve;
    }

    return state->sector[source];
}

static void remove_energy(ShieldState *state, EnergyLocation source,
                          int amount)
{
    if (source == RESERVE)
    {
        state->reserve -= amount;
    }
    else
    {
        state->sector[source] -= amount;
    }
}

static int energy_to_transfer(const ShieldState *state,
                              EnergyLocation source,
                              EnergyLocation destination,
                              int requested)
{
    int energy = available_energy(state, source);
    int capacity = available_capacity(state, destination);
    int amount = minimum(requested, energy);

    if (energy == 0 || capacity == 0)
    {
        return 0;
    }

    if (requested == energy)
    {
        amount--;
    }

    if (amount >= capacity)
    {
        amount = capacity - 1;
    }

    return amount;
}

static void transfer_energy(ShieldState *state, const Event *event)
{
    int amount = energy_to_transfer(state, event->source,
                                    event->destination,
                                    event->magnitude);

    remove_energy(state, event->source, amount);
    state->sector[event->destination] += amount;
}

static void apply_event(ShieldState *state, const Event *event)
{
    if (event->type == IMPACT)
    {
        apply_impact(state, event);
    }
    else
    {
        transfer_energy(state, event);
    }
}

static int process_events(ShieldState *state, int event_count)
{
    for (int index = 0; index < event_count; index++)
    {
        Event event = {0};

        if (!read_event(&event))
        {
            return 0;
        }

        apply_event(state, &event);
    }

    return 1;
}

static int is_operational(int energy)
{
    return energy >= OPERATIONAL_THRESHOLD;
}

static MissionReport build_report(const MissionPlan *plan,
                                  const ShieldState *final_state)
{
    MissionReport report = {0};

    report.final_state = *final_state;
    report.initial_total = total_energy(&plan->initial_state);
    report.final_total = total_energy(final_state);
    report.operational = is_operational(report.initial_total);

    return report;
}

static const char *operational_text(int operational)
{
    return operational ? "operativo" : "critico";
}

static const char *ship_text(int damage)
{
    return damage >= DESTRUCTION_THRESHOLD ? "destruida" : "activa";
}

static void print_sectors(const ShieldState *state)
{
    static const char *names[SECTOR_COUNT] = {
        "Frente", "Atras", "Izquierda", "Derecha", "Arriba", "Abajo"};

    for (int sector = 0; sector < SECTOR_COUNT; sector++)
    {
        printf("%s: %d\n", names[sector], state->sector[sector]);
    }
}

static void print_report(const MissionReport *report)
{
    printf("Energia total: %d\n", report->final_total);
    printf("Reserva: %d\n", report->final_state.reserve);
    print_sectors(&report->final_state);
    printf("Dano nave: %d\n", report->final_state.ship_damage);
    printf("Estado escudos: %s\n", operational_text(report->operational));
    printf("Estado nave: %s\n",
           ship_text(report->final_state.ship_damage));
}

int main(void)
{
    MissionPlan plan = {0};
    ShieldState current_state = {0};
    MissionReport report = {0};

    if (!read_plan(&plan))
    {
        fprintf(stderr, "Error: plan incompleto.\n");
        return 1;
    }

    if (!plan_is_valid(&plan))
    {
        fprintf(stderr, "Error: configuracion de escudos invalida.\n");
        return 1;
    }

    current_state = plan.initial_state;
    if (!process_events(&current_state, plan.event_count))
    {
        fprintf(stderr, "Error: evento invalido.\n");
        return 1;
    }

    report = build_report(&plan, &current_state);
    print_report(&report);

    return 0;
}
