/// A Fliin Pro plan as the `/pro/` page sells it (ADR 0020 §1): its launch
/// price and regular price in US dollars, taxes included, the number of
/// developers it covers, and its Polar checkout link.
typedef ProPlan = ({
  ProPlanKind kind,
  int price,
  int regular,
  int seats,
  String checkout,
});

enum ProPlanKind { solo, team }

/// The plans, in the order of the page. Fill `checkout` with the Polar
/// checkout link of each plan (`https://…`): while it is empty, the page
/// renders a disabled "Coming soon" button instead of a dead link.
const List<ProPlan> proPlans = [
  (
    kind: ProPlanKind.solo,
    price: 59,
    regular: 79,
    seats: 1,
    checkout: 'https://buy.polar.sh/polar_cl_FHBcyOzzTAgPLmJgFUQqrJOrc8DWWLl3n1iwb2k2Spy',
  ),
  (
    kind: ProPlanKind.team,
    price: 189,
    regular: 249,
    seats: 10,
    checkout: 'https://buy.polar.sh/polar_cl_AA4yJCFV8QDv03PJzVyLubGRTHvSUjWvgki8S4NStC4',
  ),
];
