export type Locale = "ar" | "en";

export interface AlertFacts {
  name: string;
  type: string;
  eventAt: Date;
}

const isolate = (s: string) => `⁨${s}⁩`;
const ltr = (s: string) => `⁦${s}⁩`;

const arabicDigits = (s: string) =>
  s.replace(/[0-9]/g, (d) => "٠١٢٣٤٥٦٧٨٩"[Number(d)]);

/** HH:mm in UTC: the server does not know the contact's time zone. */
function clock(at: Date): string {
  return at.toISOString().slice(11, 16);
}

/**
 * What a contact's phone shows. It says what SafeRide knows and no more: it
 * noticed unusual movement and got no answer. Never that an accident
 * happened, that anyone is hurt, or that emergency services were called.
 * No location, ever: a preview can be read by anyone near the phone.
 */
export function alertText(
  locale: Locale,
  facts: AlertFacts,
): { title: string; body: string } {
  const deceleration = facts.type === "suddenDeceleration";
  if (locale === "ar") {
    const name = isolate(facts.name);
    const what = deceleration ? "تباطؤ مفاجئ" : "توقف طويل";
    const time = ltr(arabicDigits(clock(facts.eventAt)));
    return {
      title: `يُرجى الاطمئنان على ${name}`,
      body:
        `لاحظ SafeRide حركة غير معتادة أثناء رحلة ${name} (${what}) ` +
        `الساعة ${time} بتوقيت UTC، ولم يصله ردّ على سؤال الأمان. ` +
        "كانت الرحلة لا تزال جارية. هذا لا يؤكد وقوع أي شيء، ولم يتصل " +
        "SafeRide بخدمات الطوارئ. جرّب الاتصال الآن.",
    };
  }
  const what = deceleration ? "a sudden slowdown" : "a long stop";
  return {
    title: `Please check on ${facts.name}`,
    body:
      `SafeRide noticed unusual movement during ${facts.name}'s journey ` +
      `(${what}) at ${clock(facts.eventAt)} UTC and got no answer to its ` +
      "safety check. The journey was still in progress. This doesn't " +
      "confirm that anything happened, and SafeRide hasn't contacted " +
      "emergency services. Try calling them now.",
  };
}
