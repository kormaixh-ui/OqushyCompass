enum TaskPriority { high, medium, low }

enum Remind { none, dayOf, dayBefore }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// When a reminder fires for a due date, or null for no reminder.
DateTime? remindTimeFor(DateTime due, Remind r) {
  switch (r) {
    case Remind.none:
      return null;
    case Remind.dayOf:
      return DateTime(due.year, due.month, due.day, 8);
    case Remind.dayBefore:
      return DateTime(due.year, due.month, due.day - 1, 18);
  }
}

class Task {
  final int id;
  String title;
  String subject;
  String notes;
  DateTime due;
  TaskPriority priority;
  Remind remind;
  bool done;
  DateTime? doneAt;
  bool sample;

  Task({
    required this.id,
    required this.title,
    this.subject = '',
    this.notes = '',
    required this.due,
    this.priority = TaskPriority.medium,
    this.remind = Remind.none,
    this.done = false,
    this.doneAt,
    this.sample = false,
  });

  DateTime? get remindAt => remindTimeFor(due, remind);
  bool get overdue => !done && due.isBefore(dateOnly(DateTime.now()));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'notes': notes,
        'due': due.toIso8601String(),
        'priority': priority.name,
        'remind': remind.name,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'sample': sample,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as int,
        title: j['title'] as String,
        subject: (j['subject'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        due: DateTime.parse(j['due'] as String),
        priority: TaskPriority.values.firstWhere((p) => p.name == j['priority'],
            orElse: () => TaskPriority.medium),
        remind: Remind.values
            .firstWhere((r) => r.name == j['remind'], orElse: () => Remind.none),
        done: (j['done'] ?? false) as bool,
        doneAt:
            j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
        sample: (j['sample'] ?? false) as bool,
      );
}
