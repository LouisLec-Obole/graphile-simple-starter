# Vue d'ensemble de Postgraphile

## Création d'une base de données
Une fois postgreSQL installé et ajouté au `PATH`, il est possible de lancer la commande 
```
createdb <le nom de ma base de donées>
```
Qui créera directement une base de donnée du nom correspondant. Si postgreSQL n'est pas ajouté au path, ou si vous préférez, il est possible d'utiliser un GUI (PGAdmin par exemple) et de créer directement votre BDD à la main. 
## Création d'un serveur express
Il existe plusieurs options pour executer Postgraphile, celle offrant le plus de contrôle et étant la plus simple à gérer vis-à-vis de la gestion des environnements de développements, de l'extensibilité, de la maintenance et j'en passe est l'utilisation de Postgraphile en *middleware* Express. Express est une bibliothèque NodeJS qui nous permet de gérer un serveur plus simplement.

Tout d'abord, nous allons créer le dossier dans lequel nous allons écrire notre API. Une fois dedans, on initialise notre projet:

```bash
yarn init -y
```

Le `-y` répond 'oui' à toutes les questions d'office.

Nous installons nos dépendances:

```bash
# Dépendance du projets
yarn add express postgraphile
# Dépendances de développement
yarn add -D dotenv
```

et nous installons tout de suite un plugin Postgraphile pour simplifier les types auto-générés dans notre schéma graphQL (plus là-dessus ensuite)

```bash
yarn add @graphile-contrib/pg-simplify-inflector
```

🎉 Tada ! On est prêt à dev !

On va maintenant créer un fichier `.env`à la racine de notre dossier dans lequel on rentre les variables d'environnement de notre projet

```bash
# Type d'environnement
NODE_ENV="development"
# Phrase de connection à postgres. Il faut un utilisateur propriétaire de la database à ce niveau
# e.g. postgresql://louis:plop@localhost:5432/capidb
DATABASE_URL="postgresql://<nom d'utilisateur>:<mdp>@<hôte>:<port>/<ma database>"
# nom du schéma de la base de données qu'on va exposer via Postgreaphile. 
# (plus là-dessus ensuite)
SCHEMA="app_public"
# Port sur lequel va écouter notre app
PORT="8976"
```

On crée un fichier `index.js` qui sera le point d'entrée de notre API. Quasi copié collé de la [doc Postgraphile](https://www.graphile.org/postgraphile/usage-library/)
```javascript index.js
// On importe les variables d'environnement
require("dotenv").config();

// On importe nos dépendences
const express = require("express");
const { postgraphile } = require("postgraphile");

// On initialise notre serveur Express
const app = express();

// On utiliste Postgraphile comme *middleware* de notre serveur Express
app.use(
  postgraphile(
    /* Postgraphile prend trois options: 
    1. Comment se connecter - nous utiliserons la phrase de connection en variable d'environnement
    2. quel schéma de la BDD exposer
    3. un objet `options`
    */
    process.env.DATABASE_URL,
    process.env.SCHEMA,
    {
      skipPlugins: [require("graphile-build").NodePlugin],
      appendPlugins: [
        // ce plugin permet de produire un schema GraphQL avec des noms plus concis et clairs
        require("@graphile-contrib/pg-simplify-inflector"),
      ],
      dynamicJson: true,
      // permissif sur les CORS en dev
      enableCors: process.env.NODE_ENV == "development",
      extendedErrors: ["hint", "detail", "errcode"],
      // GraphiQL que en dev
      graphiql: process.env.NODE_ENV == "development",
      enhanceGraphiql: true,
      // relations inverses uniquement si indexées (performance)
      ignoreIndexes: false,
      // n'expose pas ce qui n'a pas été explicitement autorisé d'accès
      ignoreRBAC: false,
      showErrorStack: "json",
      // Réagit aux modifs de BDD en dev
      watchPg: process.env.NODE_ENV == "development",
      allowExplain(req) {},
  })
);

// On lance le serveur Express
app.listen(process.env.PORT, () =>
  console.log("\n🎧 Server listening on port " + process.env.PORT + "\nGraphiQL: http://localhost:" + process.env.PORT + "/graphiql")
);
```

On n'a plus qu'à exécuter notre scripte en lançant simplement 
```bash
node .
```
dans notre terminal et notre API est lancée ! Dès que la base de données sera modifiée, l'API se remettra à jour. Pour la voir dans Graph*i*QL, on peut se rendre au lien spécifié dans le terminal.


## Schémas de base de données
Tout ça est très beau, on vient de créer notre première API mais elle se sait rien faire...pire, on a même le droit à un petit `⚠️ WARNING⚠️  You requested to use schema 'app_public'; however we couldn't find some of those! Missing schemas are: 'app_public'`.

C'est parcequ'il n'y a rien dans notre base de données, alors que c'est la base de tout.

Avant toute chose, postgres nous permet de créer des `schemas`. Ce sont simplement des conteneurs dans lesquels nous allons pouvoir créer des tables et autres objets, mais qui vont aussi nous permettre de gérer les permissions indépendament pour chaque schéma.

De manière générale, nous créons au moins deux schémas: 
- `app_public`, qui sera accessible *via* l'API (on l'a spécifié en second argument du *middleware* postgraphile un peu plus haut)
- `app_private`, qui sera plus sécurisé et non exposé directement *via* l'API. On y stockera par exemple les mots de passe.

Pour créer des schémas, on écrit nos premières commandes SQL

```sql
create schema app_public;
create schema app_private;
```
## Définitions de nos tables
Super, on a commencé à mettre en place notre schéma de base de données (attention, on distinguera par la suite "schema de base de données" avec les "schémas" de la base de données créés juste au dessus 😉) et on a plus d'erreurs si on ré-exécute notre commande `node .`... Mais notre API ne fait toujours rien ! Il va falloir rentrer dans notre BDD des choses plus intéressantes. Commençons par créer des tables. Nous allons créer un schema plutôt simple dans lequel des utilisateurs peuvent renseigner leurs bateaux. Il va nous falloir deux tables: une pour les utilisateurs, qui contiendra quelques infos de base pour les identifier, et une table pour renseigner les bateaux, et qui fera réference aux utilisateurs.

```mermaid
classDiagram
User *-- Boat : owns
User : uuid id
User : string pseudo
User : citext email
User : string phone_number
User : timestamptz birthday
User : timestamptz created_at
User : timestamptz updated_at
Boat : uuid id
Boat : string name
Boat : string constructeur
Boat : string immatriculation
Boat : float length
Boat : uuid user_id
```

En SQL, ça va donner ça :
```sql
-- on crée l'extension pgcrypto pour générer des UUID, 
-- plus sur ce sujet juste ensuite
create extension if not exists pgcrypto;
-- on crée l'extension citext (Case Insensitive Text)
-- utile pour stocker les emails notamment
create extension if not exists citext;

create table app_public.users (
  id uuid not null default gen_random_uuid() primary key,
  email citext unique not null check (email ~ '[^@]+@[^@]+\.[^@]+'),
  firstname text not null,
  phone_number text,
  birthday timestamptz not null check (birthday < now()),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_public.boats (
  id uuid not null default gen_random_uuid() primary key,
  name text,
  constructeur text,
  immatriculation text,
  length float check (length>0),
  user_id uuid not null references app_public.users
);
```

et là, ✨ magie ✨, on rouvre notre interface Graph*i*QL et un tas de choses sont apparues dans les mutations et les queries:

**-Queries-**: `user`, `users`, `boat`, `boats` et `userByEmail`

**-Mutations-**: `createBoat`, `deleteBoat`, `updateBoat`, `createUser`, `deleteUser`, `deleteUserByEmail`, `updateUser`, `updateUserByEmail`

On peut renseigner quelques fixtures pour tester:
```sql
insert into app_public.users(id, email, firstname, birthday) values
('4f1a111f-065f-4920-a408-b65bb5c076d5', 'louis@capi.com', 'Louis', '1900-12-12'),
('3e986d62-6147-433e-a690-c4c5e9536e4d', 'nicolas@capi.com', 'Nicolas', '1950-12-12'),
('a454817b-4467-4986-92a3-28c79810b8b3', 'corentin@capi.com', 'Corentin', '2019-12-12');

insert into app_public.boats( id, name, constructeur, immatriculation, length, user_id) values
('61b5f6f0-12d4-4aa6-8737-0ce81bcc7bb3', 'Bateau de louis', 'Janneau', 'XFGH1', 50, '4f1a111f-065f-4920-a408-b65bb5c076d5'),
('9f5715cf-92ff-48b4-8deb-c177f3ef8441', 'Bateau de louis 2', 'Janneau', 'XFGH145', 52, '4f1a111f-065f-4920-a408-b65bb5c076d5'),
('59dd0085-d48c-47ff-896e-fdf68f2d2829', 'Bateau de Nicolas', 'Janneau', 'XFGH2', 46, '3e986d62-6147-433e-a690-c4c5e9536e4d'),
('b16e3a75-afb3-464f-997d-843ef9bb0773', 'Bateau de Corentin', 'Janneau', 'XFGH3', 46, 'a454817b-4467-4986-92a3-28c79810b8b3');
```

L'objet de notre étude n'étant pas de découvrir GraphQl, nous n'allons pas tester ce que ça donne dans ce tutoriel, mais allez-y vous verrez que ça marche vraiment bien !!

Pour expliquer ce qui c'est passé, parceque ce n'est pas tout à fait de la magie 😏, nous allons reprendre en détail ce que nous avons renseigné dans notre SQL. Et nous allons même rajouter de petites choses.

### UUIDs
Un premier point important et l'utilisation d'UUIDs (Universally Unique IDentifiers) comme primary key de nos tables. Pourquoi ? Tout d'abord, parce que cette valeur étant assurée d'être unique dans le monde entier, elle nous permet d'avoir une référence unique pour chacun des objets de notre base de donnée. Ce sera notamment très utile plus tard pour la mise en cache dans un client GraphQL comme Apollo. Ensuite, elle ne donne pas en elle-même d'info sur la chronologie des rangs de nos tables et n'est pas devinable. Nous ne serons donc pas tenter de l'utiliser dans ce sens, ce qui n'est pas son rôle et conduit à l'occasion à des effets de bord.

Pour générer un UUID automatiquement à la création d'un rang dans notre table, nous avons utilisé l'extension `pgcrypto` qui nous fournit une fonction `gen_random_uuid()`. Ainsi, les primary keys dans la plupart de nos tables auront l'allure suivante:
```sql
create table app_public.qqchose (
  id uuid not null default gen_random_uuid() primary key,
  ...
```
### Contraintes
Postgres nous permet de définir des contraintes pour les champs de nos tables. Le plus souvent nous aurons une contrainte `primary key`sur un des champ mais nous rencontrons aussi des `unique`, `check`, `references`ou des `not null`. Chacune des ces contraintes a un impact que nous allons voir sur notre schema graphQL
#### checks
Les contraintes `check` assurent l'intégrité de la donnée dans une table. E.g. 
```sql
...
birthday timestamptz not null check (birthday < now()),
...
```
Nous assure que la date d'annoversaire d'un propriétaire sera toujours dans le passé. Comme conséquence, la mutation createUser nous renverra une erreur lorsque nous essaierons d'enregistrer un utilisateur du futur.
#### References
Faire référence à une table dans une autre commence à faire apparaître la notion de graph et donc la connection naturelle à GraphQL. En effet, en faisant une reqête sur un bateau, je peux aussi requêter son `user` car `boat` référence `user`. Attention, pour l'instant `user` ne référence pas les bateau qui lui sont associés. Pour des raisons de performance, la relations ne se fait pas dans le sens inverse (*backward relation*) tant que nous n'avons pas créé d'index sur les bateaux. L'API nous le rappelle: 
```error
Disabled 'read' permission for constraint "boats_user_id_fkey" on table "app_public"."boats" because it isn't indexed. For more information see https://graphile.org/postgraphile/best-practices/ To fix, perform

  CREATE INDEX ON "app_public"."boats"("user_id");
```

Suivons les conseils de postgraphile et créons un index:
```sql
CREATE INDEX ON app_public.boats(user_id);
```

De nouveau, ✨ magie ✨, la relation inverse est apparue. Nous pouvons maintenant effecter des requêtes sur les bateaux d'un utilisateur

```graphql
query USER_AND_BOATS {
  user(id: "blabla-uuidbla-uiblablaid"){
    id
    firstname
    boats {
      nodes {
        id
        name
      }
    }
  }
}

query BOAT_AND_ITS_USER {
  boat(id:"blablablabla-blabla") {
    id
    name
    user {
      id
      firstname
    }
  }
}
```
#### Not null
La contrainte not null force un champ à avoir une valeur. Elle assure aussi l'intégrité des données. Postgraphile détecte les champs non nuls et le reflète dans les types graphQL générés. Ainsi, le type `CreateUserInput` va être créé pour la mutation `createUser` et aura cette allure:

```
id: UUID
email: String!
firstname: String!
phoneNumber: String
birthday: Datetime!
createdAt: Datetime
updatedAt: Datetime
```

Trois cas apparaissent: 
1. le champs ne peut pas être nul mais à une valeur par défaut -> il n'est pas obligatoire *e.g. `id`*
2. le champ ne peut pas être nul et n'a pas de valeur par défaut -> il est obligatoire *e.g. `email`*
3. le champ peut être nul -> il n'est pas obligatoire *e.g. `phoneNumber`*

### Autre remarques
A COMPLETER

Inflexion

Relay Connections

Convention de nommage

On préfère mettre les contraintes à la création de la table
### Comments
Postgres nous permet de commenter notre code explicitement (comprendre: pas à la manière des développeurs). Les intérêts sont multiples:
* Tout d'abord, cela nous permet d'enrichir la documentation auto générée de notre schéma graphQL. Ajoutons le SQL suivant à notre BDD et regardons les conséquences dans graph*i*QL:
```sql
comment on table app_public.users is E'La table de notre BDD qui recense nos utilisateurs';
comment on column app_public.users.firstname is E'Le prénom de l''utilisateur';
comment on column app_public.users.email is E'L''email de l''utilisateur, unique sur la BDD';
comment on column app_public.users.birthday is E'La date de naissance de l''utilisateur';
comment on column app_public.users.phone_number is E'Le numéro de téléphone de l''utilisateur';
```
Dans l'onglet documentation, si nous regardons de plus près le type `User`, nous voyons que nous avons la decription que nous venons de rentrer à côté des champs.
* Les commentaires nous permettent comme nous allons le voir juste ensuite de maîtriser le schéma graphQL généré automatiquement par postgraphile à l'aide de **smart comments** (similaires aux smart tags abordés juste ensuite). Mettons que nous ne voulons pas générer la mutaion `createUser`, alors il nous suffira de passer le commentaire suivant sur la table `app_public.users`:

```sql
comment on table app_public.users is E'@omit create\nIci je mets ma documentation'
```

Mon conseil, n'utilisons pas les commentaires car ils n'aident pas à la maintenance. Utilisons plutôt les smart tags.
### Smart tags
TODO
### Enumérations
Dans le cas ou nous voulons proposer un ensemble de choix restreints pour la valeur d'une table, nous voudrons utiliser une **énumération**.

Comme fil conducteur nous voulons rajouter à la table `app_public.boats` l'état du navire qui peut être NEUF, COMME_NEUF, BON_ETAT ou PASSABLE.

La manière la plus directe est de créer un type énumeration dans postgres et de rajouter une colonne qui aura ce type:
```sql
create type app_public.boat_state as enum ('NEUF', 'COMME_NEUF', 'BON_ETAT', 'PASSABLE');

alter table app_public.boats add column boat_state app_public.boat_state not null;
```

Cela va aussi créer une énumération graphQL qui aura les valeurs que nous venons de définir. Nous le voyons rapidement dans graph*i*QL en parcourant la documentation ou en utilisant l'autocomplétion.

Récemment, (depuis v4.8.0), Postgraphile propose de traiter différemment les enums dû à certaines limitations liées aux enums postgres. On peut désormais utiliser les [`table enums`](https://www.graphile.org/postgraphile/enums/#with-enum-tables). Cette approche et recommandée. 

PENSER A METTRE CE DOC A JOUR
## Procédures stockées
Postgres est un serveur de BDD puissant qui nous permet aussi d'écrire directement des fonctions en BDD qui utilisent ou traitent la data. On utilisera principalement les langages SQL et PLPGSQL pour ecrire ces fonctions. Elles vont nous permettre d'étendre notre schéma graphQL en controllant plus finement ce qui va être généré depuis le-a base de données. Par exemple, la mutation `createUser` n'a pas lieu d'être, nous préferrerons avoir une mutation `register`qui viendra crypter un mot de passe, envoyer un mail de confirmation et autre. Pour obtenir cette mutation "custom" à partir de notre schéma de base de données actuel, nous allons rajouter uine fonction qui rendra cela possible. Imaginon aussi que nous souhaitions une query qui nous renvoie tous les bateaux de plus de x pieds et dont  les propriétaires sont nés après une date donnée, nous pouvons créer une fonction qui nous permettra d'obtenir ce résultat et qui sera transformée automatiquement en une query. Plus sur les fonctions dans la [documentation Postgraphile](https://www.graphile.org/postgraphile/functions/).
Quelques exemples ci-dessous:
### Custom Queries
```sql
create function app_public.boats_with_old_owners_and_very_long(boat_length float) returns setof app_public.boats as $$
  select boats.*
  from app_public.boats as boats
  inner join app_public.users as usr on usr.id = boats.user_id
  where usr.birthday < (now() - interval '10 years')
  and boats.length > $1;
$$ language sql stable;
```

donne ça:

```
query BOATS_LONGER_THAN_30 {
  boatsWithOldOwnersAndVeryLong(boatLength: 30) {
    nodes {
      id
      name
    }
  }
}
```
### Computed Columns
```sql

create function app_public.boats_length_meters(any_boat app_public.boats) returns float as $$
select $1.length/3.28;
$$ language sql stable;


create function app_public.boats_user_is_more_than_10(any_boat app_public.boats) returns boolean as $$
select (usr.birthday < (now() - interval '10 years'))
from app_public.users as usr
where usr.id = $1.user_id;
$$ language sql stable;


create function app_public.boats_is_more_than_x_feet(any_boat app_public.boats, x_feet float) returns boolean as $$
select ($1.length > $2);
$$ language sql stable;
```
donne ça
```
query BOATS_COMPUTED_COLUMNS {
  boats {
    nodes {
      id
      isMoreThanXFeet(xFeet:23)
      lengthMeters
      userIsMoreThan10
    }
  }
}
```
### Custom Mutations
### Gestion des erreurs
### SECURITY DEFINER
## Authentification
## Sécurisation
### RBAC
### RLS
## Evenements en Base de données (Triggers)
Dans une base de données, nous souhaitons parfois réagir à des évènements. Quelques cas d'exemples: après avoir créé ou modifier un bateau je souhaite par exemple mettre à jour le champ `updated_at` du propriétaire de ce bateau... Si nous avions un système de messagerie, je voudrais peut-être crer un message automatique après qu'un skipper ait accepeter une mission...
On peut écouter les évènements `insert`, `update` ou `delete`et réagir à leur suite en executant alors une procédure stockée d'allure un peu particulière.

La première étape consiste à créer cette procédure. Nous utiliserons systématiquement le language PLPGSQL pour ça:
## Tâches de fond (job queue et workers)
## Subscriptions (temps réel)
## Wrappers
## Plugings

# Environnement de développement
## Yarn workspaces
## Graphile migrate
## Azure pipelines

# Test unitaires avec Jest
## tests API
## tests BDD
## Intégration dans Azure Pipeline
