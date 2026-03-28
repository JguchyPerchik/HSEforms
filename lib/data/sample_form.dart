// lib/data/sample_form.dart
// ─── Sample JSON Schema ────────────────────────────────────────────────────────
// This demonstrates every supported field type.

const Map<String, dynamic> sampleFormJson = {
  "id": "form_001",
  "title": "Conference Registration 2025",
  "description":
      "Join us for an immersive developer conference. Fill in your details below to secure your spot.",
  "accentColor": "#6366F1",
  "showProgressBar": true,
  "confirmationMessage":
      "🎉 Thank you for registering! We'll send your confirmation to your email shortly.",
  "fields": [
    // ── Section heading ───────────────────────────────────────────────────────
    {
      "id": "heading_personal",
      "type": "heading",
      "label": "Personal Information",
      "description": null,
      "isRequired": false,
      "options": [],
      "validations": [],
    },

    // ── Short text ────────────────────────────────────────────────────────────
    {
      "id": "full_name",
      "type": "shortText",
      "label": "Full Name",
      "description": "Enter your legal name as it appears on your ID.",
      "placeholder": "e.g. Jane Doe",
      "isRequired": true,
      "options": [],
      "validations": [
        {
          "rule": "required",
          "errorMessage": "Full name is required.",
        },
        {
          "rule": "minLength",
          "value": 3,
          "errorMessage": "Name must be at least 3 characters.",
        },
      ],
    },

    // ── Short text – email ────────────────────────────────────────────────────
    {
      "id": "email",
      "type": "shortText",
      "label": "Email Address",
      "placeholder": "you@example.com",
      "isRequired": true,
      "options": [],
      "validations": [
        {"rule": "required", "errorMessage": "Email is required."},
        {"rule": "email", "errorMessage": "Please enter a valid email."},
      ],
    },

    // ── Divider ───────────────────────────────────────────────────────────────
    {
      "id": "divider_1",
      "type": "divider",
      "label": "",
      "isRequired": false,
      "options": [],
      "validations": [],
    },

    // ── Heading 2 ─────────────────────────────────────────────────────────────
    {
      "id": "heading_event",
      "type": "heading",
      "label": "Event Preferences",
      "isRequired": false,
      "options": [],
      "validations": [],
    },

    // ── Radio buttons ─────────────────────────────────────────────────────────
    {
      "id": "ticket_type",
      "type": "radio",
      "label": "Ticket Type",
      "description": "Choose the attendance format that suits you best.",
      "isRequired": true,
      "options": [
        {"id": "opt_in_person", "label": "🏛️  In-Person — Helsinki Venue"},
        {"id": "opt_virtual", "label": "💻  Virtual — Live Stream"},
        {"id": "opt_hybrid", "label": "🌐  Hybrid — Both Access"},
      ],
      "validations": [
        {"rule": "required", "errorMessage": "Please select a ticket type."},
      ],
    },

    // ── Checkboxes ────────────────────────────────────────────────────────────
    {
      "id": "workshops",
      "type": "checkbox",
      "label": "Select Workshops (choose all that apply)",
      "description": "Each workshop is 90 minutes. Pick as many as you like.",
      "isRequired": false,
      "options": [
        {"id": "ws_flutter", "label": "Flutter & Dart Deep-Dive"},
        {"id": "ws_ai", "label": "AI-Powered Mobile Apps"},
        {"id": "ws_design", "label": "Design Systems at Scale"},
        {"id": "ws_backend", "label": "Firebase & Cloud Architecture"},
        {"id": "ws_testing", "label": "Testing & CI/CD Pipelines"},
      ],
      "validations": [],
    },

    // ── Dropdown ──────────────────────────────────────────────────────────────
    {
      "id": "experience_level",
      "type": "dropdown",
      "label": "Experience Level",
      "placeholder": "Select your level",
      "isRequired": true,
      "options": [
        {"id": "exp_beginner", "label": "Beginner (< 1 year)"},
        {"id": "exp_intermediate", "label": "Intermediate (1–3 years)"},
        {"id": "exp_advanced", "label": "Advanced (3–6 years)"},
        {"id": "exp_expert", "label": "Expert (6+ years)"},
      ],
      "validations": [
        {"rule": "required", "errorMessage": "Please select your experience level."},
      ],
    },

    // ── Date picker ───────────────────────────────────────────────────────────
    {
      "id": "arrival_date",
      "type": "datePicker",
      "label": "Arrival Date",
      "description": "When do you plan to arrive in Helsinki?",
      "isRequired": false,
      "options": [],
      "validations": [],
    },

    // ── Time picker ───────────────────────────────────────────────────────────
    {
      "id": "preferred_session",
      "type": "timePicker",
      "label": "Preferred Session Start Time",
      "description": "Choose your preferred morning or afternoon slot.",
      "isRequired": false,
      "options": [],
      "validations": [],
    },

    // ── Long text ─────────────────────────────────────────────────────────────
    {
      "id": "bio",
      "type": "longText",
      "label": "Short Bio",
      "description": "Tell us a bit about yourself and what you're hoping to get from the event.",
      "placeholder": "I'm a Flutter developer with a passion for...",
      "isRequired": false,
      "rows": 4,
      "options": [],
      "validations": [
        {
          "rule": "maxLength",
          "value": 500,
          "errorMessage": "Bio must be 500 characters or fewer.",
        },
      ],
    },

    // ── Rating ────────────────────────────────────────────────────────────────
    {
      "id": "expectation_rating",
      "type": "rating",
      "label": "How excited are you for the event?",
      "description": "1 = A little curious · 5 = Can't wait!",
      "isRequired": false,
      "maxRating": 5,
      "options": [],
      "validations": [],
    },
  ],
};
