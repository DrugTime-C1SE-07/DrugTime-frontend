# DrugTime Frontend

- `mobile/`: Flutter App (bệnh nhân / người chăm sóc)
- `admin/`: Next.js Admin Dashboard
- `landing/`: Next.js Landing Page

## Cấu trúc

```
frontend/
├── .github/workflows/       # CI
├── admin/                   # Next.js App Router
│   ├── app/                 # routes: auth/, dashboard/
│   ├── components/          # layout/, medications/, interactions/, ui/
│   ├── hooks/
│   ├── lib/                 # api/, auth/, types/
│   ├── public/
│   └── tests/
├── landing/                 # Next.js App Router
│   ├── app/                 # routes: features, download, privacy-policy, terms
│   ├── components/          # layout/, sections/, ui/
│   ├── lib/seo/
│   └── public/              # icons/, images/
└── mobile/                  # Flutter
    ├── lib/
    │   ├── main.dart
    │   ├── app/             # app, router, theme
    │   ├── core/            # api, di, error, notification, storage, sync, utils
    │   ├── features/<name>/ # data/ · domain/ · presentation/
    │   └── shared/widgets/
    ├── assets/              # images/, icons/
    ├── test/                # core/, features/
    └── integration_test/
```
