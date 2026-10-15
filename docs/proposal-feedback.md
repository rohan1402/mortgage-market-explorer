# Professor Feedback on the Proposal (received after 9/30)

Pasted verbatim.

> Interesting idea with a strong real-world dataset and a clear path to the one-million-row requirement. Using actual HMDA data gives the project credibility and provides meaningful opportunities to explore indexing, aggregation, and performance at scale.
>
> * Since the HMDA data browser and other public tools already provide basic filtering, maps, and charts, think carefully about what unique value your application provides. The strongest projects solve a problem that existing tools do not solve well.
> * Make sure you create meaningful example scenarios rather than relying primarily on trend charts, loan distributions, or lender rankings. For example:
>    * A homebuyer trying to identify markets where a target loan size is common.
>    * Comparing lender activity across neighboring counties with very different lending patterns.
>    * Identifying unusual changes in lending activity across years.
>    * Exploring markets with high denial rates and understanding the reported reasons.
>    * Comparing how different lenders participate within the same market.
> * Focus on helping users answer real questions and draw useful conclusions from the data rather than simply displaying statistics. The insight is usually more valuable than the chart.
> * If you are creating visualizations, consider interactive maps, market comparisons, or guided workflows that help users investigate the data. A collection of static charts will likely feel very similar to existing public tools.
> * I also encourage you to prototype the application in Claude, Copilot, or Replit as soon as possible. Early prototypes often reveal opportunities to improve the user workflow and better differentiate the application.

## What we're doing about each point
| Feedback | Our response | Where |
|---|---|---|
| Unique value vs. Data Browser | Question-first guided investigations, always benchmarked, ending in a finding; pricing comparison no public tool offers | `PROJECT.md` §3, `investigations.md` |
| Meaningful scenarios | Three investigations covering all five examples | `investigations.md` |
| Insight over charts | Template-generated finding sentences on every result | `investigations.md` |
| Maps, comparisons, guided workflows | Map in Inv. 1, neighbor comparison in Inv. 2, step-by-step flow in all | mockups |
| Prototype early | Prototype Investigation 1 by 10/16 | `PROJECT.md` §9 |
