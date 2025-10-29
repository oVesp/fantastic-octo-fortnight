# Guia de Efeitos de Status

## Visão Geral
- Efeitos de status modificam temporariamente atributos, ações ou regras de combate.
- Dividem-se em **buffs** (benéficos), **debuffs** (prejudiciais), **controle de grupo** (impedem ações) e **estados únicos/passivos**.
- Ícones e feedback visual devem distinguir facilmente buffs (bordas verdes) e debuffs (bordas vermelhas), seguindo convenções usadas em RPGs e ARPGs.

## Buffs
- Melhoram atributos ou concedem vantagens situacionais.
- Exemplos comuns:
  - **Aumento direto de atributos**: Haste (+20% velocidade), Arcane Mind (+20% inteligência).
  - **Buffs de dano/defesa**: Berserk (+25% força, −10% defesa), Guard Up (+25% defesa), Brave (Digimon; +50% ATK/INT/crítico com HP baixo), Guts (sobrevive com 1 HP).
  - **Escudos/Invulnerabilidade**: Shield concede HP temporário; Invulnerability bloqueia dano totalmente por curta duração.
  - **Auras**: efeitos de área como Sigil of Power ou Anger aumentam atributos de aliados próximos.
- Empilhamento (stack): definir `maxStacks`; maioria dos buffs não acumula, mas efeitos como Focus podem empilhar até 3 vezes.

## Debuffs
- Reduzem atributos, causam dano ao longo do tempo ou impõem penalidades.
- **DoTs**:
  - **Poison**: dano periódico acumulável (até 3 stacks). Variantes fortes aplicam dano crescente ou impedem cura.
  - **Burn/Ignite**: dano contínuo (4 DPS base) e possíveis penalidades adicionais (redução de ataque físico).
  - **Bleed**: dano físico por segundo; pode escalar com movimento do alvo.
  - **Decay/Rot**: mistura DoT e redução/negação de cura, útil para temas sombrios.
- **Redução de atributos**: Weaken (−15% força), Slow (−20% velocidade por stack), Blind (reduz precisão), Vulnerability (reduz resistências/armadura).
- **Vulnerabilidades elementais**: Shock (+dano recebido), Scorch (−resistências), Corrosion (reduz defesa específica).

## Controle de Grupo (CC)
- Efeitos que limitam ações devem ter duração curta ou resistências específicas.
- Principais tipos:
  - **Stun/Paralyze**: bloqueiam movimento e habilidades.
  - **Freeze**: imobilização total com chance de quebrar; pode exigir interação com dano.
  - **Sleep**: impede ações até receber dano ou após tempo determinado.
  - **Silence**: bloqueia habilidades mágicas/skills (flag `NoCast`).
  - **Root/Bind**: impede deslocamento (flag `NoMove`).
  - **Confusion**: força ações aleatórias ou auto-dano.

## Efeitos Únicos
- **Taunt**: força inimigos a direcionar ataques ao provocador, útil para tanques.
- **Fear**: faz alvos recuarem ou evitarem aproximação.
- **Curse**: combina penalidades (redução de regeneração, DoT, queda de atributos).
- **Arena/Clima**: áreas que aplicam status periódicos (chão flamejante, terreno gélido). Implementar como efeitos periódicos em área.
- **Modos Temporários**: estados de carregamento, fúria ou defesa que ajustam múltiplos atributos até uma condição ser concluída.
- **Alteração elemental**: estados como Reverse que invertem vantagens de elementos.

## Duração e Acúmulo
- Definir se o jogo usa tempo real (segundos) ou turnos; o sistema atual usa segundos.
- DoTs funcionam melhor com ticks fixos (ex.: a cada 1s).
- Configurar `maxStacks` e regras de renovação:
  - Aplicações extras podem somar dano, renovar duração ou serem ignoradas.
  - Para CC fortes, preferir não acumular; apenas o maior tempo restante prevalece.
- Considerar limites para combinações (p. ex., Slow máximo de 80%).

## Passivas
- **Permanentes**: traços inerentes (ex.: resistência a veneno, redução fixa de dano físico).
- **Temporárias**: ativadas por itens/condições (ex.: buff automático ao cair abaixo de 20% HP).
- Implementar passivas via o mesmo sistema de status com duração infinita ou condicionada, facilitando modificação de atributos e flags.

## Recomendações de Implementação
1. Introduzir novos efeitos gradualmente, priorizando sinergia com mecânicas existentes.
2. Definir ícones/descrições claras para cada status.
3. Reutilizar a infraestrutura de `States` para novos efeitos (flags, modificadores, `maxStacks`).
4. Planejar resistências e imunidades parciais para monstros chefes.
5. Documentar interações especiais (ex.: molhado aumenta chance de Freeze) e criar testes automatizados/regressões.

## Próximos Passos Sugeridos
- Adicionar DoTs elementais restantes (Shock, Chill/Freeze).
- Implementar debuffs de precisão e vulnerabilidade.
- Criar status "Decay" que impede cura e aplica DoT sombrio.
- Incluir Taunt e efeitos de agro.
- Mapear sinergias/antagonismos entre status (ex.: fogo remove Freeze).
