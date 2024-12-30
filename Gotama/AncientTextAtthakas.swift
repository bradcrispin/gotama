import Foundation

enum AncientTextAtthakas {
    /// Returns the content of the Atthakas (Snp 4.2 - 4.5)
    /// This is stored separately from the main AncientText enum for better code organization
    static var content: String {
        return """
    <verse>Snp 4.2</verse>
    <pali>
    Satto guhāyaṁ bahunābhichanno,
    Tiṭṭhaṁ naro mohanasmiṁ pagāḷho;
    Dūre vivekā hi tathāvidho so,
    Kāmā hi loke na hi suppahāyā.

    Icchānidānā bhavasātabaddhā,
    Te duppamuñcā na hi aññamokkhā;
    Pacchā pure vāpi apekkhamānā,
    Ime va kāme purime va jappaṁ.

    Kāmesu giddhā pasutā pamūḷhā,
    Avadāniyā te visame niviṭṭhā;
    Dukkhūpanītā paridevayanti,
    Kiṁsū bhavissāma ito cutāse.

    Tasmā hi sikkhetha idheva jantu,
    Yaṁ kiñci jaññā visamanti loke;
    Na tassa hetū visamaṁ careyya,
    Appañhidaṁ jīvitamāhu dhīrā.

    Passāmi loke pariphandamānaṁ,
    Pajaṁ imaṁ taṇhagataṁ bhavesu;
    Hīnā narā maccumukhe lapanti,
    Avītataṇhāse bhavābhavesu.

    Mamāyite passatha phandamāne,
    Maccheva appodake khīṇasote;
    Etampi disvā amamo careyya,
    Bhavesu āsattimakubbamāno.

    Ubhosu antesu vineyya chandaṁ,
    Phassaṁ pariññāya anānugiddho;
    Yadattagarahī tadakubbamāno,
    Na lippatī diṭṭhasutesu dhīro. Variant: Na lippatī → na limpatī (sya-all, mr)

    Saññaṁ pariññā vitareyya oghaṁ,
    Pariggahesu muni nopalitto;
    Abbūḷhasallo caramappamatto,
    Nāsīsatī lokamimaṁ parañcāti. Variant: Nāsīsatī → nāsiṁsatī (bj); nāsiṁsati (sya-all, pts-vp-pli1)

    Guhaṭṭhakasuttaṁ dutiyaṁ.
    </pali>

    <verse>Snp 4.3</verse>
    <pali>
    Vadanti ve duṭṭhamanāpi eke,
    Athopi ve saccamanā vadanti;
    Vādañca jātaṁ muni no upeti,
    Tasmā munī natthi khilo kuhiñci.

    Sakañhi diṭṭhiṁ kathamaccayeyya,
    Chandānunīto ruciyā niviṭṭho;
    Sayaṁ samattāni pakubbamāno,
    Yathā hi jāneyya tathā vadeyya.

    Yo attano sīlavatāni jantu,
    Anānupuṭṭhova paresa pāva; Variant: paresa → parassa (si, mr) | pāva → pāvā (bj, sya-all, pts-vp-pli1)
    Anariyadhammaṁ kusalā tamāhu,
    Yo ātumānaṁ sayameva pāva.

    Santo ca bhikkhu abhinibbutatto,
    Itihanti sīlesu akatthamāno;
    Tamariyadhammaṁ kusalā vadanti,
    Yassussadā natthi kuhiñci loke.

    Pakappitā saṅkhatā yassa dhammā,
    Purakkhatā santi avīvadātā;
    Yadattani passati ānisaṁsaṁ,
    Taṁ nissito kuppapaṭiccasantiṁ.

    Diṭṭhīnivesā na hi svātivattā,
    Dhammesu niccheyya samuggahītaṁ;
    Tasmā naro tesu nivesanesu,
    Nirassatī ādiyatī ca dhammaṁ.

    Dhonassa hi natthi kuhiñci loke,
    Pakappitā diṭṭhi bhavābhavesu;
    Māyañca mānañca pahāya dhono,
    Sa kena gaccheyya anūpayo so.

    Upayo hi dhammesu upeti vādaṁ,
    Anūpayaṁ kena kathaṁ vadeyya;
    Attā nirattā na hi tassa atthi, Variant: nirattā → attaṁ nirattaṁ (bahūsu)
    Adhosi so diṭṭhimidheva sabbanti.

    Duṭṭhaṭṭhakasuttaṁ tatiyaṁ.
    </pali>

    <verse>Snp 4.4</verse>
    <pali>

    Passāmi suddhaṁ paramaṁ arogaṁ,
    Diṭṭhena saṁsuddhi narassa hoti;
    Evābhijānaṁ paramanti ñatvā, Variant: Evābhijānaṁ → etābhijānaṁ (bj, pts-vp-pli1)
    Suddhānupassīti pacceti ñāṇaṁ.

    Diṭṭhena ce suddhi narassa hoti,
    Ñāṇena vā so pajahāti dukkhaṁ;
    Aññena so sujjhati sopadhīko,
    Diṭṭhī hi naṁ pāva tathā vadānaṁ.

    Na brāhmaṇo aññato suddhimāha,
    Diṭṭhe sute sīlavate mute vā;
    Puññe ca pāpe ca anūpalitto,
    Attañjaho nayidha pakubbamāno.

    Purimaṁ pahāya aparaṁ sitāse,
    Ejānugā te na taranti saṅgaṁ;
    Te uggahāyanti nirassajanti,
    Kapīva sākhaṁ pamuñcaṁ gahāyaṁ. Variant: pamuñcaṁ gahāyaṁ → pamukhaṁ gahāya (bj, sya-all); pamuñcaṁ gahāya (pts-vp-pli1); pamuñca gahāya (mr)

    Sayaṁ samādāya vatāni jantu,
    Uccāvacaṁ gacchati saññasatto;
    Vidvā ca vedehi samecca dhammaṁ,
    Na uccāvacaṁ gacchati bhūripañño.

    Sa sabbadhammesu visenibhūto,
    Yaṁ kiñci diṭṭhaṁ va sutaṁ mutaṁ vā;
    Tameva dassiṁ vivaṭaṁ carantaṁ,
    Kenīdha lokasmi vikappayeyya.

    Na kappayanti na purekkharonti,
    Accantasuddhīti na te vadanti;
    Ādānaganthaṁ gathitaṁ visajja,
    Āsaṁ na kubbanti kuhiñci loke.

    Sīmātigo brāhmaṇo tassa natthi,
    Ñatvā va disvā va samuggahītaṁ; 
    Na rāgarāgī na virāgaratto,
    Tassīdha natthi paramuggahītanti.

    Suddhaṭṭhakasuttaṁ catutthaṁ.
    </pali>

    <verse>Snp 4.5</verse>
    <pali>

    Paramanti diṭṭhīsu paribbasāno,
    Yaduttari kurute jantu loke;
    Hīnāti aññe tato sabbamāha,
    Tasmā vivādāni avītivatto.

    Yadattanī passati ānisaṁsaṁ,
    Diṭṭhe sute sīlavate mute vā; Variant: sīlavate → sīlabbate (si, sya-all)
    Tadeva so tattha samuggahāya,
    Nihīnato passati sabbamaññaṁ.

    Taṁ vāpi ganthaṁ kusalā vadanti,
    Yaṁ nissito passati hīnamaññaṁ;
    Tasmā hi diṭṭhaṁ va sutaṁ mutaṁ vā,
    Sīlabbataṁ bhikkhu na nissayeyya.

    Diṭṭhimpi lokasmiṁ na kappayeyya, Variant: Diṭṭhimpi → diṭṭhimapi (mr)
    Ñāṇena vā sīlavatena vāpi;
    Samoti attānamanūpaneyya,
    Hīno na maññetha visesi vāpi.

    Attaṁ pahāya anupādiyāno,
    Ñāṇepi so nissayaṁ no karoti;
    Sa ve viyattesu na vaggasārī, Variant: viyattesu → viyuttesu (bj-a); dviyattesu (mr)
    Diṭṭhimpi so na pacceti kiñci.

    Yassūbhayante paṇidhīdha natthi,
    Bhavābhavāya idha vā huraṁ vā;
    Nivesanā tassa na santi keci,
    Dhammesu niccheyya samuggahītaṁ.

    Tassīdha diṭṭhe va sute mute vā,
    Pakappitā natthi aṇūpi saññā;
    Taṁ brāhmaṇaṁ diṭṭhimanādiyānaṁ,
    Kenīdha lokasmiṁ vikappayeyya.

    Na kappayanti na purekkharonti,
    Dhammāpi tesaṁ na paṭicchitāse;
    Na brāhmaṇo sīlavatena neyyo,
    Pāraṅgato na pacceti tādīti.

    Paramaṭṭhakasuttaṁ pañcamaṁ.
    </pali>
    """
    }
} 