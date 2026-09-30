/// EcoXchange Mobile — the real pickup time slots, transcribed verbatim
/// from the web wizard's own `<select name="pickup_time">` (`resources/
/// views/customer/pickup/create.blade.php`, confirmed by inspection) —
/// NOT invented for this app. `pickup_time` is only validated as
/// `['required', 'string', 'max:20']` server-side (no enum), but every
/// other real surface (pickup list/detail, staff/rider dashboards) expects
/// this exact `"HH:MM-HH:MM"` shape, so this app reuses the same 5 real
/// options rather than sending a free-form or differently-shaped value a
/// Flutter-only slot scheme might otherwise produce.
class PickupTimeSlot {
  const PickupTimeSlot(this.value, this.label);

  final String value;
  final String label;

  static const all = [
    PickupTimeSlot('08:00-10:00', '8:00 – 10:00 AM'),
    PickupTimeSlot('10:00-12:00', '10:00 AM – 12:00 PM'),
    PickupTimeSlot('12:00-14:00', '12:00 – 2:00 PM'),
    PickupTimeSlot('14:00-16:00', '2:00 – 4:00 PM'),
    PickupTimeSlot('16:00-18:00', '4:00 – 6:00 PM'),
  ];
}
