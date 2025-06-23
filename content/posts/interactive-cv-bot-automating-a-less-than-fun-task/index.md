---
title: "Interactive CV Bot: Automating a Less Than Fun Task"
date: 2025-06-21T14:28:00+10:00
author: "Alex Darbyshire"
slug: "interactive-cv-bot-automating-a-less-than-fun-task"
toc: true
tags:
  - LLMs 
---

It all started with a colleague asking "Could you send me a copy of a recent CV?"

In the world of consulting, it's a fairly regular ask—albeit a bit rarer for me being non-client facing.

The cogs started turning and I thought, well this will take me an hour to collate and another few to format. Then, an idea started to form—what if I could invest a bit more time now, and reduce time spent fulfilling similar requests in the future.

## The Mission

I woke up this morning with the mission—create an LLM-based chatbot with my career history as a prompt which could create a CV or resume tailored to whatever the role might be. Kind of an interesting one considering I am not actively looking for work.

Part of the brief would be a simple deployment. I had spent much of the week deep in the CI setup of multi-container Azure-based architecture. I also didn't want to re-invent the wheel writing another chatbot interface. These requirements led me to find Vercel and their Chat SDK.

Also, I wanted to chuck something together within a day. I wasn't aiming for Rome.

## Generating PDFs

I knew this would be the pointy end. Generating PDFs from web apps tends to be non-trivial, or at least fiddly. Think separate services, templating engines, old unwieldy frameworks.

Initially I was thinking of getting the LLM to render in an intermediary structured format and then going to PDF with say LaTeX. I'd skimmed a paper where they had success going to structured JSON first, and also come across approaches that went to Jinja then PDF.

I quickly realised with the lower infra approach that I needed to make do with what was available in the JavaScript world. React-PDF would have to fit the bill until there was a driver to justify a more robust solution.


### Vercel and Chat SDK

- Decent free tier
- Managed databases
- Server-side rendered pre-built chatbot which I could customise
- A bit of learning curve having never used Next.js or the Vercel AI SDK abstraction

## The Implementation

- Created a template from [`https://github.com/vercel/ai-chatbot`](https://github.com/vercel/ai-chatbot)
- Signed up for a Vercel account
- Installed Vercel via [`npm`](package.json)
- Created a Neon account for serverless PostgreSQL and an Upstash account for serverless Redis
- Worked with Claude Sonnet 4 via Roo Code
- Large system prompt injected via Base64 environment variable containing my career history
- Tool to create the structure of the PDF in React and then allow the client-side to generate a PDF

See the commit history in the [repo](https://github.com/alexdarbyshire/interactive-cv-bot).

## The Result

[`https://cv.alexdarbyshire.com/`](https://cv.alexdarbyshire.com/)

## Reflection

What started as a simple request for a CV turned into a bit of fun exploring some new tools. The combination of Vercel's deployment ease , the AI SDK's abstractions, and React-PDF's client-side generation did a 'good-enough' job.

Next time someone asks for a CV, perhaps I will share the URL and remove the middle-man (that's me). 






